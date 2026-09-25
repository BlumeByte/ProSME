alter table public.verification_subscriptions add column if not exists expiry_reminder_sent_at timestamptz;
