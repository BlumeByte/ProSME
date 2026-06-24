-- Store reusable Paystack authorizations for verification renewals and keep
-- existing verified accounts active during the paid-verification rollout.

alter table public.verification_subscriptions
  add column if not exists auto_renew boolean not null default true,
  add column if not exists paystack_customer_code text,
  add column if not exists paystack_email text,
  add column if not exists paystack_authorization_code text,
  add column if not exists paystack_authorization_signature text,
  add column if not exists paystack_authorization jsonb not null default '{}'::jsonb,
  add column if not exists payment_method_channel text,
  add column if not exists payment_method_label text,
  add column if not exists renewal_attempt_count integer not null default 0,
  add column if not exists last_renewal_attempt_at timestamptz,
  add column if not exists next_renewal_attempt_at timestamptz,
  add column if not exists last_renewal_error text,
  add column if not exists cancelled_at timestamptz;

do $$
begin
  alter table public.verification_subscriptions
    drop constraint if exists verification_subscriptions_status_check;
  alter table public.verification_subscriptions
    add constraint verification_subscriptions_status_check
    check (status in (
      'payment_required',
      'pending_payment',
      'active',
      'expired',
      'cancelled',
      'renewal_failed'
    ));
end;
$$;

do $$
begin
  alter table public.verification_payments
    drop constraint if exists verification_payments_status_check;
  alter table public.verification_payments
    add constraint verification_payments_status_check
    check (status in ('pending', 'success', 'failed', 'abandoned', 'renewal_failed'));
end;
$$;

create index if not exists verification_subscriptions_auto_renew_idx
on public.verification_subscriptions (status, auto_renew, current_period_end)
where status in ('active', 'renewal_failed');

create index if not exists verification_subscriptions_authorization_signature_idx
on public.verification_subscriptions (paystack_authorization_signature)
where paystack_authorization_signature is not null;

grant select, insert, update on public.verification_subscriptions to authenticated;
grant select, insert, update on public.verification_payments to authenticated;

insert into public.verification_subscriptions (
  user_id,
  role,
  plan_interval,
  status,
  amount_usd,
  charge_currency,
  charge_amount,
  current_period_start,
  current_period_end,
  last_payment_at,
  auto_renew,
  updated_at
)
select
  p.id,
  case when p.role = 'artisan' then 'artisan' else 'customer' end,
  'yearly',
  'active',
  case when p.role = 'artisan' then 60 else 24 end,
  'GHS',
  0,
  timezone('utc', now()),
  timezone('utc', now()) + interval '1 year',
  timezone('utc', now()),
  false,
  timezone('utc', now())
from public.profiles p
where p.role in ('customer', 'artisan')
  and p.verification_status = 'verified'
  and not exists (
    select 1
    from public.verification_subscriptions s
    where s.user_id = p.id
  );

update public.profiles p
set verification_expires_at = coalesce(p.verification_expires_at, s.current_period_end),
    updated_at = timezone('utc', now())
from public.verification_subscriptions s
where s.user_id = p.id
  and p.verification_status = 'verified'
  and s.status = 'active'
  and p.verification_expires_at is null;

create or replace function public.expire_verification_subscriptions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.verification_subscriptions
  set status = 'expired',
      auto_renew = false,
      updated_at = timezone('utc', now())
  where status in ('active', 'renewal_failed', 'pending_payment', 'payment_required')
    and current_period_end is not null
    and current_period_end < timezone('utc', now());

  update public.profiles p
  set verification_status = 'pending',
      verification_expires_at = s.current_period_end,
      updated_at = timezone('utc', now())
  from public.verification_subscriptions s
  where s.user_id = p.id
    and s.status = 'expired'
    and s.current_period_end is not null
    and s.current_period_end < timezone('utc', now())
    and p.verification_status = 'verified';
end;
$$;

revoke all on function public.expire_verification_subscriptions() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-expiry') then
    perform cron.unschedule('prosme-verification-expiry');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-expiry',
  '*/30 * * * *',
  $$
  select public.expire_verification_subscriptions();
  $$
);
