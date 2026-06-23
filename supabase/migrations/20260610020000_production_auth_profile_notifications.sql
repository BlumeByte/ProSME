-- Production hardening for auth/profile data, job images, and notification outboxes.

alter table public.profiles
add column if not exists phone_verified boolean not null default false,
add column if not exists email_notifications boolean not null default true,
add column if not exists phone_notifications boolean not null default true,
add column if not exists app_language text not null default 'English';

update public.profiles
set description = left(coalesce(description, ''), 50)
where length(coalesce(description, '')) > 50;

alter table public.profiles
drop constraint if exists profiles_description_max_50;

alter table public.profiles
add constraint profiles_description_max_50
check (length(coalesce(description, '')) <= 50);

alter table public.jobs
add column if not exists images text[] not null default '{}';

update public.jobs
set images = (coalesce(images, '{}'))[1:3]
where array_length(coalesce(images, '{}'), 1) > 3;

alter table public.jobs
drop constraint if exists jobs_images_max_3;

alter table public.jobs
add constraint jobs_images_max_3
check (coalesce(array_length(images, 1), 0) <= 3);

create table if not exists public.sms_outbox (
  id uuid primary key default gen_random_uuid(),
  to_phone text,
  body text not null default '',
  related_user_id uuid references public.profiles(id) on delete set null,
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.email_outbox (
  id uuid primary key default gen_random_uuid(),
  to_email text,
  subject text not null,
  body text not null default '',
  related_user_id uuid references public.profiles(id) on delete set null,
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  title text not null,
  body text not null default '',
  actor_id uuid references public.profiles(id) on delete set null,
  related_user_id uuid references public.profiles(id) on delete set null,
  related_table text,
  related_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.sms_outbox enable row level security;
alter table public.email_outbox enable row level security;
alter table public.admin_notifications enable row level security;

grant select, insert, update on public.sms_outbox to authenticated;

grant select, insert, update on public.email_outbox to authenticated;
grant select, insert, update on public.admin_notifications to authenticated;

drop policy if exists "Users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
create policy "Authenticated users can create email tasks"
on public.email_outbox for insert
to authenticated
with check (true);

drop policy if exists "Admins can read sms outbox" on public.sms_outbox;
create policy "Admins can read sms outbox"
on public.sms_outbox for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
create policy "Authenticated users can create sms tasks"
on public.sms_outbox for insert
to authenticated
with check (true);

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  target_profile record;
begin
  select id, email, phone, email_notifications, phone_notifications
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  if target_profile.email_notifications and coalesce(target_profile.email, '') <> '' then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (target_profile.email, email_subject, email_body, target_profile.id);
  end if;

  if target_profile.phone_notifications and coalesce(target_profile.phone, '') <> '' then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (target_profile.phone, sms_body, target_profile.id);
  end if;
end;
$$;

drop trigger if exists jobs_queue_notifications on public.jobs;
create or replace function public.queue_job_created_notifications()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
  values (
    'job_created',
    'New job request',
    new.title,
    new.created_by,
    new.created_by,
    'jobs',
    new.id
  );
  return new;
end;
$$;

create trigger jobs_queue_notifications
after insert on public.jobs
for each row execute function public.queue_job_created_notifications();

drop trigger if exists job_bids_queue_notifications on public.job_bids;
create or replace function public.queue_bid_created_notifications()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
begin
  select created_by, title
  into owner_id, job_title
  from public.jobs
  where id = new.job_id;

  perform public.queue_profile_notification(
    owner_id,
    'New ProSME bid',
    'A professional submitted a bid for "' || coalesce(job_title, 'your job') || '".',
    'New ProSME bid for ' || coalesce(job_title, 'your job') || '.'
  );

  return new;
end;
$$;

create trigger job_bids_queue_notifications
after insert on public.job_bids
for each row execute function public.queue_bid_created_notifications();

drop trigger if exists messages_queue_notifications on public.messages;
create or replace function public.queue_message_created_notifications()
returns trigger
language plpgsql
security invoker
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

  perform public.queue_profile_notification(
    recipient_id,
    'New ProSME message',
    left(coalesce(new.content, 'You have a new ProSME message.'), 200),
    left(coalesce(new.content, 'New ProSME message.'), 120)
  );

  return new;
end;
$$;

create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_created_notifications();
