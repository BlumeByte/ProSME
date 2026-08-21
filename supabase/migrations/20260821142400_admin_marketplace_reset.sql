-- Admin-only marketplace reset. Job/post content and bid records are kept;
-- only wallet ledger rows and job workflow state are reset.

create table if not exists public.marketplace_reset_audit (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references public.profiles(id) on delete restrict,
  wallet_transactions_removed integer not null check (wallet_transactions_removed >= 0),
  jobs_reopened integer not null check (jobs_reopened >= 0),
  bid_records_preserved integer not null check (bid_records_preserved >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.marketplace_reset_audit enable row level security;
revoke all on public.marketplace_reset_audit from public, anon, authenticated;
grant select on public.marketplace_reset_audit to authenticated;

drop policy if exists "Admins can read marketplace reset audit"
  on public.marketplace_reset_audit;
create policy "Admins can read marketplace reset audit"
on public.marketplace_reset_audit for select to authenticated
using (app_private.is_admin());

create or replace function public.admin_reset_marketplace(
  p_confirmation text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  wallet_count integer := 0;
  job_count integer := 0;
  bid_count integer := 0;
begin
  if caller_id is null or not app_private.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  if p_confirmation is distinct from 'RESET MARKETPLACE WORK' then
    raise exception 'The marketplace reset confirmation does not match.'
      using errcode = '22023';
  end if;

  delete from public.wallet_transactions;
  get diagnostics wallet_count = row_count;

  update public.jobs
  set
    status = 'open',
    assigned_to = null,
    accepted_bid_id = null,
    accepted_amount = null,
    work_status = 'open',
    eta_at = null,
    started_at = null,
    completed_at = null,
    status_updated_at = timezone('utc', now()),
    deleted_by_user_at = null,
    deleted_by_user_reason = null
  where status is distinct from 'open'
     or assigned_to is not null
     or accepted_bid_id is not null
     or accepted_amount is not null
     or work_status is distinct from 'open'
     or eta_at is not null
     or started_at is not null
     or completed_at is not null
     or deleted_by_user_at is not null
     or deleted_by_user_reason is not null;
  get diagnostics job_count = row_count;

  select count(*)::integer into bid_count from public.job_bids;

  insert into public.marketplace_reset_audit (
    admin_user_id,
    wallet_transactions_removed,
    jobs_reopened,
    bid_records_preserved
  ) values (
    caller_id,
    wallet_count,
    job_count,
    bid_count
  );

  return jsonb_build_object(
    'walletTransactionsRemoved', wallet_count,
    'jobsReopened', job_count,
    'bidRecordsPreserved', bid_count
  );
end;
$$;

revoke all on function public.admin_reset_marketplace(text)
  from public, anon, authenticated;
grant execute on function public.admin_reset_marketplace(text)
  to authenticated;
