-- Warn members ~3 days before their verification badge expires (email +
-- in-app notification), once per expiry cycle (guarded by
-- expiry_reminder_sent_at). Runs once a day at 09:00 UTC.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-expiry-reminders') then
    perform cron.unschedule('prosme-verification-expiry-reminders');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-expiry-reminders',
  '0 9 * * *',
  $$
  select net.http_post(
    url := 'https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/verification-billing',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-dispatch-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'email_dispatch_secret'
        limit 1
      )
    ),
    body := jsonb_build_object('action', 'sendExpiryReminders'),
    timeout_milliseconds := 20000
  );
  $$
);
