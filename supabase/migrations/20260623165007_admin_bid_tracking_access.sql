-- Give admin accounts read-only visibility for platform bid auditing.

grant select on public.job_bids to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.threads to authenticated;
grant select on public.messages to authenticated;

drop policy if exists "Admins can read all job bids" on public.job_bids;
create policy "Admins can read all job bids"
on public.job_bids for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all wallet transactions"
on public.wallet_transactions;
create policy "Admins can read all wallet transactions"
on public.wallet_transactions for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all threads" on public.threads;
create policy "Admins can read all threads"
on public.threads for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all messages" on public.messages;
create policy "Admins can read all messages"
on public.messages for select
to authenticated
using (app_private.is_admin());
