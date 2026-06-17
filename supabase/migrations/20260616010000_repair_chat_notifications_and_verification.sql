alter table public.profiles
add column if not exists email_verified boolean not null default false,
add column if not exists phone_verified boolean not null default false,
add column if not exists currency_code text not null default 'GHS';

create table if not exists public.profile_verification_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null check (channel in ('email', 'phone')),
  destination text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempt_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists profile_verification_codes_user_channel_idx
on public.profile_verification_codes (user_id, channel, created_at desc);

alter table public.profile_verification_codes enable row level security;
revoke all on public.profile_verification_codes from anon;
revoke all on public.profile_verification_codes from authenticated;

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
) returns void
language plpgsql
security definer
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

revoke all on function public.queue_profile_notification(uuid, text, text, text) from public;
revoke all on function public.queue_profile_notification(uuid, text, text, text) from anon;
revoke all on function public.queue_profile_notification(uuid, text, text, text) from authenticated;

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

  if recipient_id is not null and recipient_id <> new.sender_id then
    perform public.queue_profile_notification(
      recipient_id,
      'New ProSME message',
      left(coalesce(new.content, 'You have a new ProSME message.'), 200),
      left(coalesce(new.content, 'New ProSME message.'), 120)
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_message_created_notifications() from public;
revoke all on function public.queue_message_created_notifications() from anon;
revoke all on function public.queue_message_created_notifications() from authenticated;

drop trigger if exists messages_queue_notifications on public.messages;
create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_created_notifications();
