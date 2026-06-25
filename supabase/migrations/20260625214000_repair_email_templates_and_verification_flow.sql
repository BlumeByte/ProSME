-- Keep user-facing email alerts readable and avoid verification side-effect
-- failures caused by missing grants on recent billing/outbox tables.

grant select, insert, update on public.email_outbox to authenticated, service_role;
grant select, insert, update on public.verification_subscriptions to authenticated, service_role;
grant select, insert on public.verification_payments to authenticated, service_role;
grant select, insert, update on public.admin_notifications to authenticated, service_role;

create or replace function public.prosme_email_body_text(value text)
returns text
language plpgsql
immutable
as $$
declare
  parsed jsonb;
  parts text[];
begin
  if value is null or btrim(value) = '' then
    return 'You have a new ProSME update.';
  end if;

  if left(btrim(value), 1) not in ('{', '[') then
    return value;
  end if;

  begin
    parsed := value::jsonb;
  exception
    when others then
      return value;
  end;

  if jsonb_typeof(parsed) <> 'object' then
    return value;
  end if;

  parts := array_remove(array[
    nullif(parsed->>'message', ''),
    nullif(parsed->>'body', ''),
    nullif(parsed->>'content', ''),
    nullif(parsed->>'title', ''),
    nullif(parsed->>'description', '')
  ], null);

  if array_length(parts, 1) is not null then
    return array_to_string(parts, E'\n\n');
  end if;

  return regexp_replace(value, '[{}"]', '', 'g');
end;
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
begin
  select id, email, phone, email_notifications, phone_notifications
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  readable_body := public.prosme_email_body_text(email_body);

  if target_profile.email_notifications and coalesce(target_profile.email, '') <> '' then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (
      target_profile.email,
      coalesce(nullif(email_subject, ''), 'New ProSME update'),
      readable_body,
      target_profile.id
    );
  end if;

  if target_profile.phone_notifications and coalesce(target_profile.phone, '') <> '' then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (
      target_profile.phone,
      left(public.prosme_email_body_text(sms_body), 160),
      target_profile.id
    );
  end if;
end;
$$;

revoke all on function public.queue_profile_notification(uuid, text, text, text)
from public, anon, authenticated;

create or replace function public.queue_admin_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  readable_body text;
begin
  if new.related_user_id is null then
    return new;
  end if;

  readable_body := public.prosme_email_body_text(
    coalesce(nullif(new.body, ''), nullif(new.title, ''), 'You have a new ProSME alert.')
  );

  perform public.queue_profile_notification(
    new.related_user_id,
    coalesce(nullif(new.title, ''), 'New ProSME alert'),
    readable_body,
    left(readable_body, 120)
  );

  return new;
end;
$$;

revoke all on function public.queue_admin_notification_email()
from public, anon, authenticated;

update public.email_outbox
set body = public.prosme_email_body_text(body)
where sent_at is null
  and left(btrim(coalesce(body, '')), 1) in ('{', '[');
