-- Supabase is retiring automatic Data API grants for newly-created public
-- tables on 30 Oct 2026 (existing tables/grants are unaffected, but any
-- future `supabase db reset` or fresh branch that replays this migration
-- history would otherwise recreate these tables with no Data API access at
-- all). This migration makes the grants explicit so replays stay correct
-- regardless of that cutoff. It reproduces the exact grant set each table
-- already has today -- RLS policies remain the real access control; grants
-- are only the outer gate.
--
-- password_recovery_attempts and profile_verification_codes are
-- intentionally left ungranted to anon/authenticated: they're written and
-- read only by edge functions via the service_role key.

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on table public.admin_notifications to authenticated;
grant select, insert, update, delete on table public.admin_notifications to service_role;

grant insert on table public.analytics_events to anon;
grant select, insert, update, delete on table public.analytics_events to authenticated;
grant select, insert, update, delete on table public.analytics_events to service_role;

grant insert, update, delete on table public.applications to anon;
grant select, insert, update, delete on table public.applications to authenticated;
grant select, insert, update, delete on table public.applications to service_role;

grant select, insert, update, delete on table public.chat_blocks to authenticated;
grant select, insert, update, delete on table public.chat_blocks to service_role;

grant select, insert, update, delete on table public.device_tokens to anon;
grant select, insert, update, delete on table public.device_tokens to authenticated;
grant select, insert, update, delete on table public.device_tokens to service_role;

grant insert, update, delete on table public.email_outbox to anon;
grant select, insert, update, delete on table public.email_outbox to authenticated;
grant select, insert, update, delete on table public.email_outbox to service_role;

grant insert, update, delete on table public.job_applications to anon;
grant select, insert, update, delete on table public.job_applications to authenticated;
grant select, insert, update, delete on table public.job_applications to service_role;

grant insert, update, delete on table public.job_bids to anon;
grant select, insert, update, delete on table public.job_bids to authenticated;
grant select, insert, update, delete on table public.job_bids to service_role;

grant insert, update, delete on table public.job_messages to anon;
grant select, insert, update, delete on table public.job_messages to authenticated;
grant select, insert, update, delete on table public.job_messages to service_role;

grant insert, update, delete on table public.job_payments to anon;
grant select, insert, update, delete on table public.job_payments to authenticated;
grant select, insert, update, delete on table public.job_payments to service_role;

grant insert, update, delete on table public.job_ratings to anon;
grant select, insert, update, delete on table public.job_ratings to authenticated;
grant select, insert, update, delete on table public.job_ratings to service_role;

grant insert, update, delete on table public.job_reviews to anon;
grant select, insert, update, delete on table public.job_reviews to authenticated;
grant select, insert, update, delete on table public.job_reviews to service_role;

grant select on table public.job_status_events to authenticated;
grant select, insert, update, delete on table public.job_status_events to service_role;

grant select, insert, update, delete on table public.jobs to anon;
grant select, insert, update, delete on table public.jobs to authenticated;
grant select, insert, update, delete on table public.jobs to service_role;

grant insert, update, delete on table public.kv_store_8e58d1ea to anon;
grant select, insert, update, delete on table public.kv_store_8e58d1ea to authenticated;
grant select, insert, update, delete on table public.kv_store_8e58d1ea to service_role;

grant select, insert, update, delete on table public.listings to anon;
grant select, insert, update, delete on table public.listings to authenticated;
grant select, insert, update, delete on table public.listings to service_role;

grant select on table public.marketplace_reset_audit to authenticated;
grant select, insert, update, delete on table public.marketplace_reset_audit to service_role;

grant insert, update, delete on table public.messages to anon;
grant select, insert, update, delete on table public.messages to authenticated;
grant select, insert, update, delete on table public.messages to service_role;

grant select, insert, update, delete on table public.password_recovery_attempts to service_role;

grant select, insert, update, delete on table public.profile_verification_codes to service_role;

grant select, insert, update, delete on table public.profiles to anon;
grant select, insert, update, delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.profiles to service_role;

grant select, insert, update, delete on table public.push_outbox to anon;
grant select, insert, update, delete on table public.push_outbox to authenticated;
grant select, insert, update, delete on table public.push_outbox to service_role;

grant select, insert, update, delete on table public.reports to authenticated;
grant select, insert, update, delete on table public.reports to service_role;

grant insert, update, delete on table public.saved_listings to anon;
grant select, insert, update, delete on table public.saved_listings to authenticated;
grant select, insert, update, delete on table public.saved_listings to service_role;

grant select, insert, update, delete on table public.sms_outbox to authenticated;
grant select, insert, update, delete on table public.sms_outbox to service_role;

grant insert, update, delete on table public.threads to anon;
grant select, insert, update, delete on table public.threads to authenticated;
grant select, insert, update, delete on table public.threads to service_role;

grant select, insert, update, delete on table public.user_thread_deletions to authenticated;
grant select, insert, update, delete on table public.user_thread_deletions to service_role;

grant select, insert, update, delete on table public.verification_payments to authenticated;
grant select, insert, update, delete on table public.verification_payments to service_role;

grant select, insert, update, delete on table public.verification_requests to authenticated;
grant select, insert, update, delete on table public.verification_requests to service_role;

grant select, insert, update, delete on table public.verification_subscriptions to authenticated;
grant select, insert, update, delete on table public.verification_subscriptions to service_role;

grant select on table public.wallet_reset_audit to authenticated;
grant select, insert, update, delete on table public.wallet_reset_audit to service_role;

grant select on table public.wallet_transactions to authenticated;
grant select, insert, update, delete on table public.wallet_transactions to service_role;
