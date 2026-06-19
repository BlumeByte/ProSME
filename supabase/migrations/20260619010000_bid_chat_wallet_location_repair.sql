-- Repair bid notification trigger permissions and add wallet/location tracking.

alter table public.jobs
add column if not exists location_lat double precision,
add column if not exists location_lng double precision,
add column if not exists location_source text not null default 'typed',
add column if not exists accepted_bid_id uuid references public.job_bids(id) on delete set null,
add column if not exists accepted_amount numeric(12, 2);

alter table public.job_bids
add column if not exists location text,
add column if not exists location_lat double precision,
add column if not exists location_lng double precision,
add column if not exists location_source text not null default 'not_shared';

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  bid_id uuid references public.job_bids(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  artisan_id uuid references public.profiles(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'GHS',
  event_type text not null default 'bid_accepted'
    check (event_type in ('bid_accepted', 'payment_recorded', 'refund_recorded')),
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists wallet_transactions_bid_event_uidx
on public.wallet_transactions (bid_id, event_type)
where bid_id is not null;

alter table public.wallet_transactions enable row level security;
grant select, insert on public.wallet_transactions to authenticated;
revoke all on public.wallet_transactions from anon;

grant delete on public.admin_notifications to authenticated;

drop policy if exists "Users can delete own notifications" on public.admin_notifications;
create policy "Users can delete own notifications"
on public.admin_notifications for delete
to authenticated
using (
  related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

drop policy if exists "Users can read own wallet transactions" on public.wallet_transactions;
create policy "Users can read own wallet transactions"
on public.wallet_transactions for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

drop policy if exists "Authenticated can insert wallet transactions through app" on public.wallet_transactions;
create policy "Authenticated can insert wallet transactions through app"
on public.wallet_transactions for insert
to authenticated
with check (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

create or replace function public.queue_bid_created_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
begin
  select created_by, title
  into owner_id, job_title
  from public.jobs
  where id = new.job_id;

  if owner_id is not null and owner_id <> new.artisan_id then
    perform public.queue_profile_notification(
      owner_id,
      'New ProSME bid',
      'A professional submitted a bid for "' || coalesce(job_title, 'your job') || '".',
      'New ProSME bid for ' || coalesce(job_title, 'your job') || '.'
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_bid_created_notifications() from public;
revoke all on function public.queue_bid_created_notifications() from anon;
revoke all on function public.queue_bid_created_notifications() from authenticated;

drop trigger if exists job_bids_queue_notifications on public.job_bids;
create trigger job_bids_queue_notifications
after insert on public.job_bids
for each row execute function public.queue_bid_created_notifications();

create or replace function public.record_bid_acceptance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title
    into owner_id, job_title
    from public.jobs
    where id = new.job_id;

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'completed'
    where id = new.job_id;

    insert into public.wallet_transactions (job_id, bid_id, user_id, artisan_id, amount)
    values (new.job_id, new.id, owner_id, new.artisan_id, new.amount)
    on conflict do nothing;

    insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
    values
      ('bid_accepted', 'Bid accepted', 'Your bid was accepted for "' || coalesce(job_title, 'a job') || '". Chat is now open.', owner_id, new.artisan_id, 'job_bids', new.id),
      ('bid_accepted', 'Bid accepted', 'You accepted a bid for "' || coalesce(job_title, 'your job') || '". Chat is now open.', new.artisan_id, owner_id, 'job_bids', new.id);
  end if;

  return new;
end;
$$;

revoke all on function public.record_bid_acceptance() from public;
revoke all on function public.record_bid_acceptance() from anon;
revoke all on function public.record_bid_acceptance() from authenticated;

drop trigger if exists job_bids_record_acceptance on public.job_bids;
create trigger job_bids_record_acceptance
after update of status on public.job_bids
for each row execute function public.record_bid_acceptance();
