-- 1. Single source of truth for the cron dispatch secret -------------------
-- pg_cron jobs (prosme-email-outbox-dispatch, drain-push-outbox,
-- prosme-verification-renewals/reconcile/expiry-reminders) send the secret
-- they read from Vault (vault.decrypted_secrets, name 'email_dispatch_secret')
-- as the x-email-dispatch-secret header. The edge functions were instead
-- checking an Edge Function env var of a similar name, which nothing ever
-- set to the same value — so every cron-triggered call failed with
-- "Missing session." / "Missing admin session." This RPC lets a function's
-- service-role client read the exact same Vault value, so there is only
-- ever one place this secret lives.
create or replace function public.get_email_dispatch_secret()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'email_dispatch_secret' limit 1;
$$;

revoke all on function public.get_email_dispatch_secret() from public, anon, authenticated;
grant execute on function public.get_email_dispatch_secret() to service_role;

-- 2. Branded newsletter-style broadcast email -------------------------------
-- Matches the look of supabase/functions/_shared/email_template.ts (the
-- shell every other ProSME email now uses): logo header, white card, a real
-- button per link instead of a bare <a>, and a footer linking to the site.
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
  select
    '<!doctype html><html><body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;padding:28px 16px;"><tr><td align="center">'
    || '<table role="presentation" width="100%" style="max-width:568px;" cellpadding="0" cellspacing="0">'
    || '<tr><td align="center" style="padding:0 0 20px"><img src="https://prosme.blumebyte.com/prosme_logo.png" width="48" height="48" alt="ProSME" style="border-radius:10px;display:block" /></td></tr>'
    || '<tr><td style="background:#ffffff;border-radius:16px;padding:32px 28px;box-shadow:0 1px 3px rgba(0,0,0,0.06)">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">'
    || '<tr><td style="font-family:Arial,Helvetica,sans-serif;font-size:21px;font-weight:bold;color:#0f1b3d;padding:0 0 14px">'
    || app_private.esc_html(p_title) || '</td></tr>'
    || case when p_image ~* '^https://'
         then '<tr><td style="padding:0 0 20px"><img src="' || app_private.esc_html(p_image)
              || '" alt="" width="536" style="width:100%;max-width:536px;border-radius:12px;display:block" /></td></tr>'
         else '' end
    || '<tr><td style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#1f2937;padding:0 0 4px">'
    || replace(app_private.esc_html(p_body), E'\n', '<br>') || '</td></tr>'
    || coalesce((
         select string_agg(
           '<tr><td style="padding:10px 0 0"><table role="presentation" cellpadding="0" cellspacing="0"><tr>'
             || '<td style="border-radius:8px;background:#0F6B4A">'
             || '<a href="' || app_private.esc_html(l->>'url')
             || '" style="display:inline-block;padding:13px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px">'
             || app_private.esc_html(coalesce(nullif(l->>'label', ''), l->>'url')) || '</a>'
             || '</td></tr></table></td></tr>',
           '' order by ord)
         from jsonb_array_elements(coalesce(p_links, '[]'::jsonb)) with ordinality as x(l, ord)
         where l->>'url' ~* '^https://'
       ), '')
    || '</table></td></tr>'
    || '<tr><td align="center" style="padding:22px 12px 0;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:#9ca3af">'
    || 'ProSME &middot; Find trusted professionals fast<br/>'
    || '<a href="https://prosme.blumebyte.com" style="color:#0F6B4A;text-decoration:none">prosme.blumebyte.com</a><br/>'
    || 'You are receiving this because of your ProSME notification settings. Manage them any time in the app under Profile &rarr; App settings.'
    || '</td></tr>'
    || '</table></td></tr></table></body></html>';
$$;
