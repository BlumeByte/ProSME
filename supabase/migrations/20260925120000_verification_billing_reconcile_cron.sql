-- Failsafe: reconcile verification payments left stuck at 'pending_payment'
-- (client closed the tab, network dropped, or the Paystack webhook itself
-- failed to deliver) by checking each one directly against Paystack.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-reconcile') then
    perform cron.unschedule('prosme-verification-reconcile');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-reconcile',
  '*/10 * * * *',
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
    body := jsonb_build_object('action', 'reconcilePending', 'limit', 50),
    timeout_milliseconds := 20000
  );
  $$
);
