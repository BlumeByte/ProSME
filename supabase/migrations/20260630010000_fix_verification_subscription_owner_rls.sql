-- Allow users to create or refresh their own unpaid verification subscription
-- after uploading documents. Paystack success and activation remain server-side.

grant select, insert, update, delete on public.verification_subscriptions
to authenticated, service_role;

drop policy if exists "Users can create own unpaid verification subscriptions"
on public.verification_subscriptions;
create policy "Users can create own unpaid verification subscriptions"
on public.verification_subscriptions
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'payment_required'
  and plan_interval in ('monthly', 'yearly')
  and role in ('customer', 'artisan')
  and amount_usd = case
    when role = 'artisan' then 5::numeric
    else 2::numeric
  end
  and role = coalesce((
    select p.role
    from public.profiles p
    where p.id = (select auth.uid())
  ), '')
);

drop policy if exists "Users can refresh own unpaid verification subscriptions"
on public.verification_subscriptions;
create policy "Users can refresh own unpaid verification subscriptions"
on public.verification_subscriptions
for update
to authenticated
using (
  user_id = (select auth.uid())
  and status in ('payment_required', 'pending_payment', 'expired', 'cancelled')
)
with check (
  user_id = (select auth.uid())
  and status = 'payment_required'
  and plan_interval in ('monthly', 'yearly')
  and role in ('customer', 'artisan')
  and amount_usd = case
    when role = 'artisan' then 5::numeric
    else 2::numeric
  end
  and role = coalesce((
    select p.role
    from public.profiles p
    where p.id = (select auth.uid())
  ), '')
);
