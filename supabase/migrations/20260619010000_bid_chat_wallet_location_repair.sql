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
  invoice_number text,
  job_title text not null default '',
  job_location text not null default '',
  customer_name text not null default '',
  customer_email text not null default '',
  artisan_name text not null default '',
  artisan_email text not null default '',
  payment_status text not null default 'agreed'
    check (payment_status in ('agreed', 'paid', 'refunded')),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.wallet_transactions
add column if not exists invoice_number text,
add column if not exists job_title text not null default '',
add column if not exists job_location text not null default '',
add column if not exists customer_name text not null default '',
add column if not exists customer_email text not null default '',
add column if not exists artisan_name text not null default '',
add column if not exists artisan_email text not null default '',
add column if not exists payment_status text not null default 'agreed';

create unique index if not exists wallet_transactions_invoice_number_uidx
on public.wallet_transactions (invoice_number)
where invoice_number is not null;

create unique index if not exists wallet_transactions_bid_event_uidx
on public.wallet_transactions (bid_id, event_type)
where bid_id is not null;

alter table public.wallet_transactions enable row level security;
grant select on public.wallet_transactions to authenticated;
revoke insert, update, delete on public.wallet_transactions from authenticated;
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
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
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
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated can insert wallet transactions through app" on public.wallet_transactions;

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
  job_location text;
  customer_name text;
  customer_email text;
  artisan_name text;
  artisan_email text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title, location
    into owner_id, job_title, job_location
    from public.jobs
    where id = new.job_id;

    select
      coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Customer'),
      coalesce(email, '')
    into customer_name, customer_email
    from public.profiles
    where id = owner_id;

    select
      coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Artisan'),
      coalesce(email, '')
    into artisan_name, artisan_email
    from public.profiles
    where id = new.artisan_id;

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'completed'
    where id = new.job_id;

    insert into public.wallet_transactions (
      job_id,
      bid_id,
      user_id,
      artisan_id,
      amount,
      invoice_number,
      job_title,
      job_location,
      customer_name,
      customer_email,
      artisan_name,
      artisan_email
    )
    values (
      new.job_id,
      new.id,
      owner_id,
      new.artisan_id,
      new.amount,
      'PSME-' || upper(substr(replace(new.id::text, '-', ''), 1, 12)),
      coalesce(job_title, ''),
      coalesce(job_location, ''),
      coalesce(customer_name, 'Customer'),
      coalesce(customer_email, ''),
      coalesce(artisan_name, 'Artisan'),
      coalesce(artisan_email, '')
    )
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

-- Populate wallets for bids that were accepted before this migration existed.
insert into public.wallet_transactions (
  job_id,
  bid_id,
  user_id,
  artisan_id,
  amount,
  invoice_number,
  job_title,
  job_location,
  customer_name,
  customer_email,
  artisan_name,
  artisan_email,
  created_at
)
select
  b.job_id,
  b.id,
  j.created_by,
  b.artisan_id,
  b.amount,
  'PSME-' || upper(substr(replace(b.id::text, '-', ''), 1, 12)),
  coalesce(j.title, ''),
  coalesce(j.location, ''),
  coalesce(nullif(customer.full_name, ''), nullif(customer.username, ''), customer.email, 'Customer'),
  coalesce(customer.email, ''),
  coalesce(nullif(artisan.full_name, ''), nullif(artisan.username, ''), artisan.email, 'Artisan'),
  coalesce(artisan.email, ''),
  coalesce(b.updated_at, b.created_at, timezone('utc', now()))
from public.job_bids b
join public.jobs j on j.id = b.job_id
left join public.profiles customer on customer.id = j.created_by
left join public.profiles artisan on artisan.id = b.artisan_id
where b.status = 'accepted'
on conflict do nothing;

with accepted as (
  select distinct on (b.job_id)
    b.job_id,
    b.id,
    b.amount
  from public.job_bids b
  where b.status = 'accepted'
  order by b.job_id, b.updated_at desc nulls last, b.created_at desc
)
update public.jobs j
set accepted_bid_id = accepted.id,
    accepted_amount = accepted.amount,
    status = 'completed'
from accepted
where accepted.job_id = j.id
  and j.accepted_bid_id is null;
