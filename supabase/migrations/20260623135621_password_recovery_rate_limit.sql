create table if not exists public.password_recovery_attempts (
  id bigint generated always as identity primary key,
  email_hash text not null,
  requested_at timestamptz not null default timezone('utc', now())
);

create index if not exists password_recovery_attempts_lookup_idx
on public.password_recovery_attempts (email_hash, requested_at desc);

alter table public.password_recovery_attempts enable row level security;

revoke all on public.password_recovery_attempts from public, anon, authenticated;
revoke all on sequence public.password_recovery_attempts_id_seq from public, anon, authenticated;
grant select, insert, delete on public.password_recovery_attempts to service_role;
grant usage, select on sequence public.password_recovery_attempts_id_seq to service_role;
