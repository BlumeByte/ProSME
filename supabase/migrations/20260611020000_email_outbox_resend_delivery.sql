alter table public.email_outbox
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists last_error text,
  add column if not exists resend_message_id text;

create index if not exists email_outbox_pending_idx
on public.email_outbox (created_at)
where sent_at is null;
