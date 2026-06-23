-- Email user-facing alerts and flush queued email tasks automatically.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;
create extension if not exists supabase_vault with schema vault;

create or replace function public.queue_admin_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.related_user_id is null then
    return new;
  end if;

  perform public.queue_profile_notification(
    new.related_user_id,
    coalesce(nullif(new.title, ''), 'New ProSME alert'),
    coalesce(nullif(new.body, ''), 'You have a new ProSME alert.'),
    left(coalesce(nullif(new.body, ''), nullif(new.title, ''), 'New ProSME alert.'), 120)
  );

  return new;
end;
$$;

revoke all on function public.queue_admin_notification_email()
from public, anon, authenticated;

drop trigger if exists admin_notifications_queue_email on public.admin_notifications;
create trigger admin_notifications_queue_email
after insert on public.admin_notifications
for each row execute function public.queue_admin_notification_email();

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-email-outbox-dispatch') then
    perform cron.unschedule('prosme-email-outbox-dispatch');
  end if;
end;
$$;

select cron.schedule(
  'prosme-email-outbox-dispatch',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/send-email-outbox',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-dispatch-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'email_dispatch_secret'
        limit 1
      )
    ),
    body := jsonb_build_object('limit', 25, 'maxAttempts', 5),
    timeout_milliseconds := 10000
  );
  $$
);
