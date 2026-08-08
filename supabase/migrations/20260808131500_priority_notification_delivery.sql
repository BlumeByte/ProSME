-- ProSME priority notification delivery policy.
-- Keep routine delivery focused on events users must act on:
-- bids, being hired/booked, job/work changes, and account/security/settings.

begin;

create or replace function public.prosme_notification_type(value text)
returns text
language plpgsql
immutable
as $$
declare
  normalized text;
begin
  normalized := lower(coalesce(value, ''));

  if normalized like '%bid%' or normalized like '%proposal%' or normalized like '%quote%' then
    return 'bid';
  elsif normalized like '%booking%'
     or normalized like '%booked%'
     or normalized like '%hire%'
     or normalized like '%hired%'
     or normalized like '%assigned%' then
    return 'booking';
  elsif normalized like '%job%'
     or normalized like '%work%'
     or normalized like '%milestone%'
     or normalized like '%project%'
     or normalized like '%completed%'
     or normalized like '%started%'
     or normalized like '%progress%' then
    return 'job';
  elsif normalized like '%account%'
     or normalized like '%password%'
     or normalized like '%profile%'
     or normalized like '%login%'
     or normalized like '%sign in%'
     or normalized like '%security%'
     or normalized like '%setting%' then
    return 'account';
  elsif normalized like '%chat%' or normalized like '%message%' then
    return 'chat';
  elsif normalized like '%payment%'
     or normalized like '%wallet%'
     or normalized like '%invoice%'
     or normalized like '%billing%' then
    return 'payment';
  elsif normalized like '%verification%' or normalized like '%verify%' then
    return 'verification';
  elsif normalized like '%support%' or normalized like '%report%' then
    return 'support';
  end if;

  return 'system';
end;
$$;

create or replace function public.prosme_is_priority_notification_type(notification_type text)
returns boolean
language sql
immutable
as $$
  select coalesce(notification_type, 'system') = any(array['bid','booking','job','account']::text[]);
$$;

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile record;
  readable_body text;
  notification_type text;
begin
  select
    id,
    email,
    phone,
    email_notifications,
    phone_notifications,
    blocked_email_notification_types,
    blocked_phone_notification_types
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  readable_body := public.prosme_email_body_text(email_body);
  notification_type := public.prosme_notification_type(
    concat_ws(' ', email_subject, email_body, sms_body)
  );

  if not public.prosme_is_priority_notification_type(notification_type) then
    return;
  end if;

  if (target_profile.email_notifications or notification_type = 'account')
     and coalesce(target_profile.email, '') <> ''
     and not public.prosme_blocks_notification_type(
       target_profile.blocked_email_notification_types,
       notification_type
     ) then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (
      target_profile.email,
      coalesce(nullif(email_subject, ''), 'New ProSME update'),
      readable_body,
      target_profile.id
    );
  end if;

  -- Existing "phone notifications" are SMS delivery. In-app device alerts are
  -- handled separately by the mobile client while it is active.
  if target_profile.phone_notifications
     and coalesce(target_profile.phone, '') <> ''
     and not public.prosme_blocks_notification_type(
       target_profile.blocked_phone_notification_types,
       notification_type
     ) then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (
      target_profile.phone,
      left(public.prosme_email_body_text(sms_body), 160),
      target_profile.id
    );
  end if;
end;
$$;

-- Default existing accounts before the account-change trigger exists, so the
-- migration itself does not generate user-facing security alerts.
update public.profiles
set blocked_email_notification_types = (
  select array_agg(distinct value order by value)
  from unnest(coalesce(blocked_email_notification_types, '{}'::text[]) || array['chat','payment','verification','support','system']::text[]) value
),
blocked_phone_notification_types = (
  select array_agg(distinct value order by value)
  from unnest(coalesce(blocked_phone_notification_types, '{}'::text[]) || array['chat','payment','verification','support','system']::text[]) value
);

-- Every priority in-app notification becomes the single source of truth for
-- outbound email/SMS. This keeps work-progress and accepted-bid alerts aligned
-- and prevents each feature from implementing delivery differently.
create or replace function public.deliver_priority_admin_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_type text;
begin
  if new.related_user_id is null then
    return new;
  end if;

  notification_type := public.prosme_notification_type(
    concat_ws(' ', new.type, new.title, new.body)
  );

  if public.prosme_is_priority_notification_type(notification_type) then
    perform public.queue_profile_notification(
      new.related_user_id,
      new.title,
      new.body,
      new.body
    );
  end if;

  return new;
end;
$$;

drop trigger if exists admin_notifications_priority_delivery
on public.admin_notifications;
create trigger admin_notifications_priority_delivery
after insert on public.admin_notifications
for each row execute function public.deliver_priority_admin_notification();

-- New bids must appear in the in-app feed first. The delivery trigger above
-- then sends the allowed email/SMS exactly once.
create or replace function public.queue_bid_created_notifications()
returns trigger
language plpgsql
security definer
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

  if owner_id is not null and owner_id <> new.artisan_id then
    insert into public.admin_notifications (
      type,
      title,
      body,
      actor_id,
      related_user_id,
      related_table,
      related_id
    ) values (
      'bid_created',
      'New ProSME bid',
      'A professional submitted a bid for "' || coalesce(job_title, 'your job') || '".',
      new.artisan_id,
      owner_id,
      'job_bids',
      new.id
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_bid_created_notifications()
from public, anon, authenticated;

drop trigger if exists job_bids_queue_notifications on public.job_bids;
create trigger job_bids_queue_notifications
after insert on public.job_bids
for each row execute function public.queue_bid_created_notifications();

-- Notify a user when important account settings change. Ordinary bio/portfolio
-- edits are intentionally excluded to avoid email noise.
create or replace function public.notify_profile_account_setting_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.email is distinct from new.email
     or old.phone is distinct from new.phone
     or old.username is distinct from new.username
     or old.email_notifications is distinct from new.email_notifications
     or old.phone_notifications is distinct from new.phone_notifications
     or old.blocked_email_notification_types is distinct from new.blocked_email_notification_types
     or old.blocked_phone_notification_types is distinct from new.blocked_phone_notification_types then
    insert into public.admin_notifications (
      type,
      title,
      body,
      actor_id,
      related_user_id,
      related_table,
      related_id
    ) values (
      'account_settings_changed',
      'Account settings changed',
      'Your ProSME account settings were updated. If you did not make this change, review your account security.',
      new.id,
      new.id,
      'profiles',
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_account_setting_change_notification
on public.profiles;
create trigger profiles_account_setting_change_notification
after update of email, phone, username, email_notifications, phone_notifications,
  blocked_email_notification_types, blocked_phone_notification_types
on public.profiles
for each row execute function public.notify_profile_account_setting_change();

revoke all on function public.prosme_is_priority_notification_type(text)
from public, anon, authenticated;
revoke all on function public.prosme_notification_type(text)
from public, anon, authenticated;
revoke all on function public.queue_profile_notification(uuid, text, text, text)
from public, anon, authenticated;
revoke all on function public.deliver_priority_admin_notification()
from public, anon, authenticated;
revoke all on function public.notify_profile_account_setting_change()
from public, anon, authenticated;

commit;
