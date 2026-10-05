-- Security hardening, part 2: least-privilege grants, anonymous column limits,
-- function execute lockdown and abuse (SMS/e-mail/push flooding) controls.

-- ---------------------------------------------------------------------------
-- 1. Grants. RLS is the real gate, but anon held full DML (and everyone held
--    TRUNCATE/TRIGGER/REFERENCES) on every table. Keep only what the app uses.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- Logged-out visitors may record analytics and browse the public feed.
grant insert on public.analytics_events to anon;
grant select on public.listings to anon;
grant select (id, title, description, location, budget, created_by, created_at,
              status, images, work_status, request_type)
  on public.jobs to anon;
-- Profiles: public marketplace fields only. Contact details, date of birth,
-- gender, mobile-money number, ID document paths and review notes are never
-- readable without signing in.
grant select (id, username, full_name, avatar_url, role, verification_status,
              is_busy, description, country, country_code, categories,
              location, bio, rating_summary, created_at, updated_at)
  on public.profiles to anon;

-- New tables must not silently become anon-readable.
do $$
begin
  execute 'alter default privileges in schema public revoke all on tables from anon';
  execute 'alter default privileges in schema public revoke all on functions from anon';
exception when others then
  raise notice 'default privilege change skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Trigger-only SECURITY DEFINER functions must not be callable as RPCs.
-- ---------------------------------------------------------------------------
revoke execute on function public.queue_admin_notification_push() from public, anon, authenticated;
revoke execute on function public.queue_job_posted_alerts() from public, anon, authenticated;
revoke execute on function public.queue_job_created_notifications() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Rate limiting primitives (fixed window counters).
-- ---------------------------------------------------------------------------
create table if not exists app_private.rate_limits (
  bucket       text        not null,
  window_start timestamptz not null,
  hits         integer     not null default 0,
  primary key (bucket, window_start)
);
alter table app_private.rate_limits enable row level security;
revoke all on app_private.rate_limits from public, anon, authenticated;

create or replace function app_private.hit_rate_limit(
  p_bucket text, p_max integer, p_window_seconds integer
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  w timestamptz :=
    to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  h integer;
begin
  insert into app_private.rate_limits as r (bucket, window_start, hits)
  values (p_bucket, w, 1)
  on conflict (bucket, window_start)
  do update set hits = r.hits + 1
  returning r.hits into h;

  if random() < 0.01 then
    delete from app_private.rate_limits where window_start < now() - interval '2 days';
  end if;

  return h <= p_max;
end;
$$;

revoke all on function app_private.hit_rate_limit(text, integer, integer) from public, anon;
-- app_private is not exposed through the API, so granting execute here only
-- lets the triggers below (which run as the calling role) use it.
grant execute on function app_private.hit_rate_limit(text, integer, integer) to authenticated;

-- RPC wrapper for edge functions (service role only).
create or replace function public.rate_limit_hit(
  p_bucket text, p_max integer, p_window_seconds integer
) returns boolean
language sql
security definer
set search_path = ''
as $$
  select app_private.hit_rate_limit(p_bucket, p_max, p_window_seconds);
$$;
revoke all on function public.rate_limit_hit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.rate_limit_hit(text, integer, integer) to service_role;

-- Client IP as forwarded by the API gateway (used to throttle anonymous writes).
create or replace function app_private.request_ip()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(split_part(coalesce(
      (nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for'), ''), ',', 1), ''),
    'unknown'
  );
$$;
grant execute on function app_private.request_ip() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Throttle direct client writes that fan out to e-mail / SMS / push, or that
--    are otherwise cheap to spam. Triggers run as the invoking role, so rows
--    produced by SECURITY DEFINER server triggers (current_user = postgres) and
--    by the service role are never counted against a user.
-- ---------------------------------------------------------------------------
create or replace function app_private.limit_message_rate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated'
     and not app_private.hit_rate_limit('msg:' || new.sender_id::text, 40, 60) then
    raise exception 'You are sending messages too quickly. Please wait a moment.'
      using errcode = '54000';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_rate_limit on public.messages;
create trigger messages_rate_limit
  before insert on public.messages
  for each row execute function app_private.limit_message_rate();

create or replace function app_private.limit_notification_rate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated'
     and not app_private.hit_rate_limit('notif:' || coalesce(new.actor_id::text, 'unknown'), 20, 3600) then
    raise exception 'Too many requests. Please try again later.' using errcode = '54000';
  end if;
  return new;
end;
$$;

drop trigger if exists admin_notifications_rate_limit on public.admin_notifications;
create trigger admin_notifications_rate_limit
  before insert on public.admin_notifications
  for each row execute function app_private.limit_notification_rate();

create or replace function app_private.limit_email_outbox_rate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated'
     and not app_private.hit_rate_limit('email:' || coalesce(new.related_user_id::text, 'unknown'), 10, 3600) then
    raise exception 'Too many requests. Please try again later.' using errcode = '54000';
  end if;
  return new;
end;
$$;

drop trigger if exists email_outbox_rate_limit on public.email_outbox;
create trigger email_outbox_rate_limit
  before insert on public.email_outbox
  for each row execute function app_private.limit_email_outbox_rate();

create or replace function app_private.limit_analytics_rate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated')
     and not app_private.hit_rate_limit('analytics:' || app_private.request_ip(), 120, 60) then
    raise exception 'Too many requests.' using errcode = '54000';
  end if;
  return new;
end;
$$;

drop trigger if exists analytics_events_rate_limit on public.analytics_events;
create trigger analytics_events_rate_limit
  before insert on public.analytics_events
  for each row execute function app_private.limit_analytics_rate();

-- A chat message e-mails/texts the recipient. Without a throttle, one user
-- could drive unlimited SMS spend to another user. Notify at most once per
-- sender -> recipient every 10 minutes (in-app delivery is unaffected).
create or replace function public.queue_message_created_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
begin
  select case
    when t.user_id = new.sender_id then t.artisan_id
    else t.user_id
  end
  into recipient_id
  from public.threads t
  where t.id = new.thread_id;

  if recipient_id is not null
     and recipient_id <> new.sender_id
     and app_private.hit_rate_limit(
       'msgnotif:' || recipient_id::text || ':' || new.sender_id::text, 1, 600) then
    perform public.queue_profile_notification(
      recipient_id,
      'New ProSME chat message',
      'You have a new chat message in ProSME. Open the app to read and reply.',
      'New ProSME chat message. Open the app to reply.'
    );
  end if;

  return new;
end;
$$;
revoke execute on function public.queue_message_created_notifications() from public, anon, authenticated;
