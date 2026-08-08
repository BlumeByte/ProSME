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

  -- Routine email/SMS delivery is intentionally restricted to priority events.
  if not public.prosme_is_priority_notification_type(notification_type) then
    return;
  end if;

  if target_profile.email_notifications
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

-- Default existing accounts to the requested priority categories while still
-- preserving explicit user opt-outs for those categories.
update public.profiles
set blocked_email_notification_types = (
  select array_agg(distinct value order by value)
  from unnest(coalesce(blocked_email_notification_types, '{}'::text[]) || array['chat','payment','verification','support','system']::text[]) value
),
blocked_phone_notification_types = (
  select array_agg(distinct value order by value)
  from unnest(coalesce(blocked_phone_notification_types, '{}'::text[]) || array['chat','payment','verification','support','system']::text[]) value
);

revoke all on function public.prosme_is_priority_notification_type(text)
from public, anon, authenticated;

revoke all on function public.prosme_notification_type(text)
from public, anon, authenticated;

revoke all on function public.queue_profile_notification(uuid, text, text, text)
from public, anon, authenticated;

commit;
