-- Attempt automatic verification renewals through the billing Edge Function.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-renewals') then
    perform cron.unschedule('prosme-verification-renewals');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-renewals',
  '*/30 * * * *',
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
    body := jsonb_build_object('action', 'renewDue', 'limit', 50),
    timeout_milliseconds := 20000
  );
  $$
);
