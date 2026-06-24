-- Paid verification subscriptions. Admin approval makes payment required;
-- a verified Paystack payment activates or renews the public badge.

alter table public.profiles
  add column if not exists verification_expires_at timestamptz;

create table if not exists public.verification_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('customer', 'artisan')),
  plan_interval text not null check (plan_interval in ('monthly', 'yearly')),
  status text not null default 'payment_required'
    check (status in ('payment_required', 'pending_payment', 'active', 'expired', 'cancelled')),
  amount_usd numeric(10, 2) not null,
  charge_currency text not null default 'GHS',
  charge_amount integer not null default 0,
  paystack_reference text unique,
  paystack_access_code text,
  paystack_authorization_url text,
  paystack_transaction_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  admin_approved_by uuid references public.profiles(id) on delete set null,
  admin_approved_at timestamptz,
  last_payment_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id)
);

create table if not exists public.verification_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.verification_subscriptions(id) on delete set null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('customer', 'artisan')),
  plan_interval text not null check (plan_interval in ('monthly', 'yearly')),
  status text not null default 'pending'
    check (status in ('pending', 'success', 'failed', 'abandoned')),
  amount_usd numeric(10, 2) not null,
  charge_currency text not null,
  charge_amount integer not null,
  paystack_reference text not null unique,
  paystack_transaction_id text,
  gateway_response text,
  paid_at timestamptz,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists verification_subscriptions_user_status_idx
on public.verification_subscriptions (user_id, status);

create index if not exists verification_subscriptions_period_end_idx
on public.verification_subscriptions (current_period_end);

create index if not exists verification_payments_user_created_idx
on public.verification_payments (user_id, created_at desc);

alter table public.verification_subscriptions enable row level security;
alter table public.verification_payments enable row level security;

grant select, insert, update on public.verification_subscriptions to authenticated;
grant select, insert, update on public.verification_payments to authenticated;
revoke all on public.verification_subscriptions from anon;
revoke all on public.verification_payments from anon;

drop policy if exists "Users can read own verification subscriptions"
on public.verification_subscriptions;
create policy "Users can read own verification subscriptions"
on public.verification_subscriptions
for select
to authenticated
using (user_id = (select auth.uid()) or app_private.is_admin());

drop policy if exists "Admins can manage verification subscriptions"
on public.verification_subscriptions;
create policy "Admins can manage verification subscriptions"
on public.verification_subscriptions
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists "Users can read own verification payments"
on public.verification_payments;
create policy "Users can read own verification payments"
on public.verification_payments
for select
to authenticated
using (user_id = (select auth.uid()) or app_private.is_admin());

drop policy if exists "Admins can manage verification payments"
on public.verification_payments;
create policy "Admins can manage verification payments"
on public.verification_payments
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create or replace function public.expire_verification_subscriptions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.verification_subscriptions
  set status = 'expired',
      updated_at = timezone('utc', now())
  where status = 'active'
    and current_period_end < timezone('utc', now());

  update public.profiles p
  set verification_status = 'pending',
      verification_expires_at = s.current_period_end,
      updated_at = timezone('utc', now())
  from public.verification_subscriptions s
  where s.user_id = p.id
    and s.status = 'expired'
    and p.verification_status = 'verified';
end;
$$;

revoke all on function public.expire_verification_subscriptions() from public, anon, authenticated;
