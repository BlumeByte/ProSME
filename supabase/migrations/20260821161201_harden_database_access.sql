-- Harden internal notification helpers against search_path manipulation.
alter function public.prosme_email_body_text(text)
  set search_path = '';

alter function public.prosme_blocks_notification_type(text[], text)
  set search_path = '';

alter function public.prosme_notification_type(text)
  set search_path = '';

-- These helpers are invoked by trusted database routines and are not public APIs.
revoke all on function public.prosme_email_body_text(text)
  from public, anon, authenticated;
grant execute on function public.prosme_email_body_text(text)
  to service_role;

revoke all on function public.prosme_blocks_notification_type(text[], text)
  from public, anon, authenticated;
grant execute on function public.prosme_blocks_notification_type(text[], text)
  to service_role;

revoke all on function public.prosme_notification_type(text)
  from public, anon, authenticated;
grant execute on function public.prosme_notification_type(text)
  to service_role;

-- Remove anonymous API discovery/access from private operational tables. RLS
-- already denied rows, but explicit revocation provides a second boundary.
revoke all on table public.sms_outbox from anon;
revoke all on table public.user_thread_deletions from anon;
revoke all on table public.verification_requests from anon;
