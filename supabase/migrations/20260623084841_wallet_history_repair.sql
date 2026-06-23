-- Make wallet tracking idempotent, backfill historical wins, and keep bid
-- outcomes queryable for customer, artisan, and developer history screens.

alter table public.jobs
add column if not exists accepted_bid_id uuid
  references public.job_bids(id) on delete set null,
add column if not exists accepted_amount numeric(12, 2);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  bid_id uuid references public.job_bids(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  artisan_id uuid references public.profiles(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'GHS',
  event_type text not null default 'bid_accepted',
  invoice_number text,
  job_title text not null default '',
  job_location text not null default '',
  customer_name text not null default '',
  customer_email text not null default '',
  artisan_name text not null default '',
  artisan_email text not null default '',
  payment_status text not null default 'agreed',
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.wallet_transactions
add column if not exists job_id uuid references public.jobs(id) on delete set null,
add column if not exists bid_id uuid references public.job_bids(id) on delete set null,
add column if not exists user_id uuid references public.profiles(id) on delete set null,
add column if not exists artisan_id uuid references public.profiles(id) on delete set null,
add column if not exists amount numeric(12, 2),
add column if not exists currency text not null default 'GHS',
add column if not exists event_type text not null default 'bid_accepted',
add column if not exists invoice_number text,
add column if not exists job_title text not null default '',
add column if not exists job_location text not null default '',
add column if not exists customer_name text not null default '',
add column if not exists customer_email text not null default '',
add column if not exists artisan_name text not null default '',
add column if not exists artisan_email text not null default '',
add column if not exists payment_status text not null default 'agreed',
add column if not exists created_at timestamptz not null default timezone('utc', now()),
add column if not exists work_status text not null default 'accepted',
add column if not exists completed_at timestamptz;

create unique index if not exists wallet_transactions_bid_event_uidx
on public.wallet_transactions (bid_id, event_type)
where bid_id is not null;

create unique index if not exists wallet_transactions_invoice_number_uidx
on public.wallet_transactions (invoice_number)
where invoice_number is not null;

alter table public.wallet_transactions
drop constraint if exists wallet_transactions_work_status_check;

alter table public.wallet_transactions
add constraint wallet_transactions_work_status_check
check (work_status in ('accepted', 'completed', 'cancelled'));

create index if not exists wallet_transactions_user_created_idx
on public.wallet_transactions (user_id, created_at desc);

create index if not exists wallet_transactions_artisan_created_idx
on public.wallet_transactions (artisan_id, created_at desc);

create index if not exists job_bids_artisan_status_created_idx
on public.job_bids (artisan_id, status, created_at desc);

create index if not exists job_bids_job_status_created_idx
on public.job_bids (job_id, status, created_at desc);

create index if not exists jobs_owner_status_created_idx
on public.jobs (created_by, status, created_at desc);

grant select on public.wallet_transactions to authenticated;
revoke insert, update, delete on public.wallet_transactions from authenticated;
revoke all on public.wallet_transactions from anon;

drop policy if exists "Users can read own wallet transactions"
on public.wallet_transactions;
create policy "Users can read own wallet transactions"
on public.wallet_transactions for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'developer')
  )
);

create or replace function public.sync_wallet_transaction_for_bid(
  p_bid_id uuid,
  p_work_status text default 'accepted'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  bid_row public.job_bids%rowtype;
  job_row public.jobs%rowtype;
  customer_name_value text;
  customer_email_value text;
  artisan_name_value text;
  artisan_email_value text;
begin
  select * into bid_row
  from public.job_bids
  where id = p_bid_id;

  if bid_row.id is null or bid_row.status <> 'accepted' then
    return;
  end if;

  select * into job_row
  from public.jobs
  where id = bid_row.job_id;

  if job_row.id is null then
    return;
  end if;

  select
    coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Customer'),
    coalesce(email, '')
  into customer_name_value, customer_email_value
  from public.profiles
  where id = job_row.created_by;

  select
    coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Artisan'),
    coalesce(email, '')
  into artisan_name_value, artisan_email_value
  from public.profiles
  where id = bid_row.artisan_id;

  insert into public.wallet_transactions as existing (
    job_id,
    bid_id,
    user_id,
    artisan_id,
    amount,
    currency,
    event_type,
    invoice_number,
    job_title,
    job_location,
    customer_name,
    customer_email,
    artisan_name,
    artisan_email,
    work_status,
    completed_at,
    created_at
  ) values (
    job_row.id,
    bid_row.id,
    job_row.created_by,
    bid_row.artisan_id,
    bid_row.amount,
    'GHS',
    'bid_accepted',
    'PSME-' || upper(substr(replace(bid_row.id::text, '-', ''), 1, 12)),
    coalesce(job_row.title, ''),
    coalesce(job_row.location, ''),
    coalesce(customer_name_value, 'Customer'),
    coalesce(customer_email_value, ''),
    coalesce(artisan_name_value, 'Artisan'),
    coalesce(artisan_email_value, ''),
    case when p_work_status = 'completed' then 'completed' else 'accepted' end,
    case
      when p_work_status = 'completed' then timezone('utc', now())
      else null
    end,
    coalesce(bid_row.updated_at, bid_row.created_at, timezone('utc', now()))
  )
  on conflict (bid_id, event_type) where bid_id is not null
  do update set
    amount = excluded.amount,
    job_title = excluded.job_title,
    job_location = excluded.job_location,
    customer_name = excluded.customer_name,
    customer_email = excluded.customer_email,
    artisan_name = excluded.artisan_name,
    artisan_email = excluded.artisan_email,
    work_status = case
      when excluded.work_status = 'completed' then 'completed'
      else existing.work_status
    end,
    completed_at = coalesce(
      existing.completed_at,
      excluded.completed_at
    );
end;
$$;

revoke all on function public.sync_wallet_transaction_for_bid(uuid, text)
from public, anon, authenticated;

create or replace function public.record_bid_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  job_title_value text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title
    into owner_id, job_title_value
    from public.jobs
    where id = new.job_id;

    update public.job_bids
    set status = 'rejected'
    where job_id = new.job_id
      and id <> new.id
      and status = 'pending';

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'completed'
    where id = new.job_id;

    perform public.sync_wallet_transaction_for_bid(
      new.id,
      case
        when exists (
          select 1 from public.jobs j
          where j.id = new.job_id and j.status = 'completed'
        ) then 'completed'
        else 'accepted'
      end
    );

    insert into public.admin_notifications (
      type,
      title,
      body,
      actor_id,
      related_user_id,
      related_table,
      related_id
    ) values
      (
        'bid_accepted',
        'Bid accepted',
        'Your bid was accepted for "' || coalesce(job_title_value, 'a job') || '". Chat is now open.',
        owner_id,
        new.artisan_id,
        'job_bids',
        new.id
      ),
      (
        'bid_accepted',
        'Bid accepted',
        'You accepted a bid for "' || coalesce(job_title_value, 'your job') || '". Chat is now open.',
        new.artisan_id,
        owner_id,
        'job_bids',
        new.id
      );
  end if;

  return new;
end;
$$;

revoke all on function public.record_bid_acceptance()
from public, anon, authenticated;

drop trigger if exists job_bids_record_acceptance on public.job_bids;
create trigger job_bids_record_acceptance
after update of status on public.job_bids
for each row execute function public.record_bid_acceptance();

create or replace function public.record_completed_job_wallet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepted_id uuid;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    accepted_id := new.accepted_bid_id;

    if accepted_id is null then
      select b.id into accepted_id
      from public.job_bids b
      where b.job_id = new.id and b.status = 'accepted'
      order by b.updated_at desc nulls last, b.created_at desc
      limit 1;
    end if;

    if accepted_id is not null then
      perform public.sync_wallet_transaction_for_bid(accepted_id, 'completed');
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.record_completed_job_wallet()
from public, anon, authenticated;

drop trigger if exists jobs_record_completed_wallet on public.jobs;
create trigger jobs_record_completed_wallet
after update of status on public.jobs
for each row execute function public.record_completed_job_wallet();

-- Normalize historical data before enforcing one winning bid per request.
with ranked_acceptances as (
  select
    b.id,
    row_number() over (
      partition by b.job_id
      order by
        case when j.accepted_bid_id = b.id then 0 else 1 end,
        b.updated_at desc nulls last,
        b.created_at desc
    ) as position
  from public.job_bids b
  join public.jobs j on j.id = b.job_id
  where b.status = 'accepted'
)
update public.job_bids b
set status = 'rejected'
from ranked_acceptances ranked
where ranked.id = b.id
  and ranked.position > 1;

create unique index if not exists job_bids_one_accepted_per_job_uidx
on public.job_bids (job_id)
where status = 'accepted';

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
where accepted.job_id = j.id;

update public.job_bids pending
set status = 'rejected'
where pending.status = 'pending'
  and exists (
    select 1
    from public.job_bids accepted
    where accepted.job_id = pending.job_id
      and accepted.status = 'accepted'
  );

do $$
declare
  accepted_record record;
begin
  for accepted_record in
    select
      b.id,
      case when j.status = 'completed' then 'completed' else 'accepted' end
        as work_status
    from public.job_bids b
    join public.jobs j on j.id = b.job_id
    where b.status = 'accepted'
  loop
    perform public.sync_wallet_transaction_for_bid(
      accepted_record.id,
      accepted_record.work_status
    );
  end loop;
end;
$$;
