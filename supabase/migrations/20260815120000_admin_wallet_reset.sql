-- Admin-only wallet ledger reset with explicit confirmation and audit history.

create table if not exists public.wallet_reset_audit (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references public.profiles(id) on delete restrict,
  target_user_id uuid references public.profiles(id) on delete set null,
  affected_rows integer not null check (affected_rows >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.wallet_reset_audit enable row level security;
revoke all on public.wallet_reset_audit from public, anon, authenticated;
grant select on public.wallet_reset_audit to authenticated;

drop policy if exists "Admins can read wallet reset audit"
  on public.wallet_reset_audit;
create policy "Admins can read wallet reset audit"
on public.wallet_reset_audit for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);

create or replace function public.admin_reset_wallet(
  p_user_id uuid default null,
  p_confirmation text default ''
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  deleted_count integer := 0;
  expected_confirmation text;
begin
  if caller_id is null or not exists (
    select 1
    from public.profiles p
    where p.id = caller_id
      and p.role = 'admin'
  ) then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  expected_confirmation := case
    when p_user_id is null then 'RESET ALL WALLETS'
    else 'RESET USER WALLET'
  end;

  if p_confirmation is distinct from expected_confirmation then
    raise exception 'The wallet reset confirmation does not match.'
      using errcode = '22023';
  end if;

  if p_user_id is not null and not exists (
    select 1 from public.profiles p where p.id = p_user_id
  ) then
    raise exception 'The selected user does not exist.' using errcode = 'P0002';
  end if;

  if p_user_id is null then
    delete from public.wallet_transactions;
  else
    delete from public.wallet_transactions wt
    where wt.user_id = p_user_id
       or wt.artisan_id = p_user_id;
  end if;
  get diagnostics deleted_count = row_count;

  insert into public.wallet_reset_audit (
    admin_user_id,
    target_user_id,
    affected_rows
  ) values (
    caller_id,
    p_user_id,
    deleted_count
  );

  return deleted_count;
end;
$$;

revoke all on function public.admin_reset_wallet(uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_reset_wallet(uuid, text)
  to authenticated;
