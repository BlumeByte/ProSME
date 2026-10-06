-- Email notifications and admin broadcasts.
--
-- Every email goes into public.email_outbox and is sent by the
-- send-email-outbox function (every minute, via pg_cron). Each queued email is
-- checked against the recipient's opt-outs in profiles.blocked_email_notification_types
-- and profiles.email_notifications before it is queued.
--
-- Categories (match kNotificationTypeOptions in the app):
--   bid, payment (wallet), chat, account (profile), new_user (admins only),
--   broadcast, app_update

alter table public.email_outbox add column if not exists html text;

create or replace function app_private.esc_html(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select replace(replace(replace(replace(coalesce(value, ''),
    '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

create or replace function app_private.email_allowed(p_user uuid, p_category text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_user
      and coalesce(p.email, '') <> ''
      and coalesce(p.email_notifications, true)
      and not (coalesce(p.blocked_email_notification_types, '{}'::text[]) @> array[p_category])
  );
$$;

create or replace function app_private.queue_email(
  p_user uuid,
  p_category text,
  p_subject text,
  p_body text,
  p_html text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null or not app_private.email_allowed(p_user, p_category) then
    return;
  end if;
  insert into public.email_outbox (to_email, subject, body, html, related_user_id)
  values (null, p_subject, p_body, p_html, p_user);
end;
$$;

-- Bids -------------------------------------------------------------------
create or replace function app_private.notify_new_bid()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  job_title text;
begin
  select j.created_by, j.title into owner_id, job_title
  from public.jobs j
  where j.id = new.job_id;
  if owner_id is not null and owner_id is distinct from new.created_by_user_id then
    perform app_private.queue_email(
      owner_id,
      'bid',
      'New bid on your job',
      'An artisan placed a bid of ' || new.amount::text || ' on your job "' || coalesce(job_title, '') || '". Open ProSME to review it.'
    );
  end if;
  return null;
end;
$$;

drop trigger if exists job_bids_notify_insert on public.job_bids;
create trigger job_bids_notify_insert
  after insert on public.job_bids
  for each row execute function app_private.notify_new_bid();

create or replace function app_private.notify_bid_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and new.artisan_id is not null then
    perform app_private.queue_email(
      new.artisan_id,
      'bid',
      'Bid update: ' || new.status,
      'Your bid is now ' || new.status || '. Open ProSME to see the details.'
    );
  end if;
  return null;
end;
$$;

drop trigger if exists job_bids_notify_status on public.job_bids;
create trigger job_bids_notify_status
  after update of status on public.job_bids
  for each row execute function app_private.notify_bid_status();

-- Wallet -----------------------------------------------------------------
create or replace function app_private.notify_wallet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  body_text text;
begin
  body_text := 'Your wallet was updated: '
    || coalesce(new.event_type, 'transaction') || ', '
    || new.amount::text || ' ' || coalesce(new.currency, 'GHS')
    || case when new.job_title is not null then ' for "' || new.job_title || '"' else '' end
    || '.';
  perform app_private.queue_email(new.user_id, 'payment', 'Wallet update on ProSME', body_text);
  if new.artisan_id is distinct from new.user_id then
    perform app_private.queue_email(new.artisan_id, 'payment', 'Wallet update on ProSME', body_text);
  end if;
  return null;
end;
$$;

drop trigger if exists wallet_transactions_notify on public.wallet_transactions;
create trigger wallet_transactions_notify
  after insert on public.wallet_transactions
  for each row execute function app_private.notify_wallet();

-- Chat -------------------------------------------------------------------
create or replace function app_private.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  thread_user uuid;
  thread_artisan uuid;
  recipient uuid;
begin
  select t.user_id, t.artisan_id into thread_user, thread_artisan
  from public.threads t
  where t.id = new.thread_id;
  recipient := case when new.sender_id = thread_user then thread_artisan else thread_user end;
  if recipient is null or recipient = new.sender_id then
    return null;
  end if;
  -- At most one "new message" email per person every 10 minutes.
  if exists (
    select 1 from public.email_outbox e
    where e.related_user_id = recipient
      and e.subject = 'New message on ProSME'
      and e.created_at > now() - interval '10 minutes'
  ) then
    return null;
  end if;
  perform app_private.queue_email(
    recipient,
    'chat',
    'New message on ProSME',
    'You have a new message on ProSME. Open the Chat tab to read and reply.'
  );
  return null;
end;
$$;

drop trigger if exists messages_notify_insert on public.messages;
create trigger messages_notify_insert
  after insert on public.messages
  for each row execute function app_private.notify_new_message();

-- New users and profile changes -----------------------------------------
create or replace function app_private.notify_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin_row record;
begin
  -- Spreadsheet imports create many accounts at once; do not email admins for each.
  if new.account_source = 'imported' then
    return null;
  end if;
  for admin_row in
    select id from public.profiles where role = 'admin' and id <> new.id
  loop
    perform app_private.queue_email(
      admin_row.id,
      'new_user',
      'New user joined ProSME',
      coalesce(nullif(new.full_name, ''), nullif(new.username, ''), 'A new user')
        || ' (' || coalesce(new.email, 'no email') || ') joined as '
        || coalesce(new.role, 'customer') || '.'
    );
  end loop;
  return null;
end;
$$;

drop trigger if exists profiles_notify_new_user on public.profiles;
create trigger profiles_notify_new_user
  after insert on public.profiles
  for each row execute function app_private.notify_new_user();

create or replace function app_private.notify_verification_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_status is distinct from old.verification_status
     and new.verification_status in ('verified', 'rejected') then
    perform app_private.queue_email(
      new.id,
      'account',
      'Your ProSME verification is ' || new.verification_status,
      'Your verification status is now ' || new.verification_status || '. Open ProSME for details.'
    );
  end if;
  return null;
end;
$$;

drop trigger if exists profiles_notify_verification on public.profiles;
create trigger profiles_notify_verification
  after update of verification_status on public.profiles
  for each row execute function app_private.notify_verification_change();

-- Broadcasts --------------------------------------------------------------
create table if not exists public.broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 150),
  body text not null default '' check (char_length(body) <= 5000),
  image_url text,
  links jsonb not null default '[]'::jsonb,
  category text not null default 'broadcast' check (category in ('broadcast', 'app_update')),
  channel text not null default 'both' check (channel in ('app', 'email', 'both')),
  audience text not null default 'all' check (audience in ('all', 'customer', 'artisan')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  recipient_count integer not null default 0
);

alter table public.broadcasts enable row level security;

drop policy if exists "Admins manage broadcasts" on public.broadcasts;
create policy "Admins manage broadcasts" on public.broadcasts
  for all to authenticated
  using ((select app_private.is_admin()))
  with check ((select app_private.is_admin()));

create or replace function app_private.broadcast_html(
  p_title text,
  p_body text,
  p_image text,
  p_links jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select '<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#111827;line-height:1.55">'
    || '<h2 style="color:#0f1b3d;margin:0 0 12px">' || app_private.esc_html(p_title) || '</h2>'
    || case when p_image ~* '^https://'
         then '<img src="' || app_private.esc_html(p_image) || '" alt="" style="max-width:100%;border-radius:8px;margin:0 0 12px">'
         else '' end
    || '<p style="margin:0 0 12px">' || replace(app_private.esc_html(p_body), E'\n', '<br>') || '</p>'
    || coalesce((
         select string_agg(
           '<p style="margin:0 0 8px"><a href="' || app_private.esc_html(l->>'url') || '" style="color:#0f1b3d">'
             || app_private.esc_html(coalesce(nullif(l->>'label', ''), l->>'url')) || '</a></p>',
           '' order by ord)
         from jsonb_array_elements(coalesce(p_links, '[]'::jsonb)) with ordinality as x(l, ord)
         where l->>'url' ~* '^https://'
       ), '')
    || '<p style="color:#6b7280;font-size:12px;margin-top:20px">You are receiving this because of your ProSME notification settings.</p>'
    || '</div>';
$$;

create or replace function app_private.fan_out_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  html text;
  total integer;
begin
  html := app_private.broadcast_html(new.title, new.body, new.image_url, new.links);

  if new.channel in ('app', 'both') then
    insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
    select new.category, new.title, new.body, new.created_by, p.id, 'broadcasts', new.id
    from public.profiles p
    where (new.audience = 'all' or p.role = new.audience)
      and not (coalesce(p.blocked_email_notification_types, '{}'::text[]) @> array[new.category]);
  end if;

  if new.channel in ('email', 'both') then
    insert into public.email_outbox (to_email, subject, body, html, related_user_id)
    select null, new.title, new.body, html, p.id
    from public.profiles p
    where (new.audience = 'all' or p.role = new.audience)
      and coalesce(p.email, '') <> ''
      and coalesce(p.email_notifications, true)
      and not (coalesce(p.blocked_email_notification_types, '{}'::text[]) @> array[new.category]);
  end if;

  select count(*) into total
  from public.profiles p
  where (new.audience = 'all' or p.role = new.audience);
  update public.broadcasts set recipient_count = total where id = new.id;
  return null;
end;
$$;

drop trigger if exists broadcasts_fan_out on public.broadcasts;
create trigger broadcasts_fan_out
  after insert on public.broadcasts
  for each row execute function app_private.fan_out_broadcast();

-- Image uploads for broadcasts (public read, admin write).
insert into storage.buckets (id, name, public)
values ('broadcast-images', 'broadcast-images', true)
on conflict (id) do nothing;

drop policy if exists "Admins upload broadcast images" on storage.objects;
create policy "Admins upload broadcast images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'broadcast-images' and (select app_private.is_admin()));

drop policy if exists "Public read broadcast images" on storage.objects;
create policy "Public read broadcast images" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'broadcast-images');
