alter table public.jobs
add column if not exists work_status text not null default 'open',
add column if not exists eta_at timestamptz,
add column if not exists started_at timestamptz,
add column if not exists completed_at timestamptz,
add column if not exists status_updated_at timestamptz not null default timezone('utc', now());

alter table public.jobs
drop constraint if exists jobs_work_status_check;

alter table public.jobs
add constraint jobs_work_status_check
check (work_status in ('open', 'accepted', 'in_progress', 'completed', 'cancelled'));

create table if not exists public.job_status_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  status text not null
    check (status in ('open', 'accepted', 'in_progress', 'completed', 'cancelled')),
  note text,
  eta_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists job_status_events_job_created_idx
on public.job_status_events (job_id, created_at);

alter table public.job_status_events enable row level security;
grant select on public.job_status_events to authenticated;
revoke insert, update, delete on public.job_status_events from anon, authenticated;
revoke all on public.job_status_events from anon;

drop policy if exists "Participants can read job timeline" on public.job_status_events;
create policy "Participants can read job timeline"
on public.job_status_events for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_status_events.job_id
      and (
        j.created_by = (select auth.uid())
        or exists (
          select 1
          from public.job_bids b
          where b.job_id = j.id
            and b.artisan_id = (select auth.uid())
            and b.status = 'accepted'
        )
        or exists (
          select 1
          from public.profiles p
          where p.id = (select auth.uid())
            and p.role in ('admin', 'developer')
        )
      )
  )
);

create or replace function public.update_job_progress(
  p_job_id uuid,
  p_status text,
  p_eta_at timestamptz default null,
  p_note text default null
)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  current_job public.jobs%rowtype;
  accepted_artisan uuid;
  actor_role text;
  next_status text := lower(trim(coalesce(p_status, '')));
begin
  if actor is null then
    raise exception 'Authentication required';
  end if;
  if next_status not in ('accepted', 'in_progress', 'completed', 'cancelled') then
    raise exception 'Invalid job status';
  end if;

  select * into current_job
  from public.jobs
  where id = p_job_id
  for update;
  if current_job.id is null then
    raise exception 'Job not found';
  end if;

  select b.artisan_id into accepted_artisan
  from public.job_bids b
  where b.job_id = p_job_id and b.status = 'accepted'
  order by b.updated_at desc nulls last, b.created_at desc
  limit 1;
  select p.role into actor_role from public.profiles p where p.id = actor;

  if actor <> current_job.created_by
     and actor is distinct from accepted_artisan
     and coalesce(actor_role, '') not in ('admin', 'developer') then
    raise exception 'Only job participants can update progress';
  end if;
  if accepted_artisan is null and next_status <> 'cancelled' then
    raise exception 'Accept a bid before updating progress';
  end if;
  if current_job.work_status = 'completed' and next_status <> 'completed' then
    raise exception 'Completed jobs cannot be reopened';
  end if;
  if current_job.work_status = 'in_progress' and next_status = 'accepted' then
    raise exception 'Work in progress cannot move back to accepted';
  end if;
  if current_job.work_status = 'cancelled' then
    raise exception 'Cancelled jobs cannot be updated';
  end if;

  update public.jobs
  set work_status = next_status,
      eta_at = coalesce(p_eta_at, eta_at),
      started_at = case
        when next_status = 'in_progress' then coalesce(started_at, timezone('utc', now()))
        else started_at
      end,
      completed_at = case
        when next_status = 'completed' then coalesce(completed_at, timezone('utc', now()))
        else completed_at
      end,
      status_updated_at = timezone('utc', now()),
      status = case
        when next_status = 'completed' then 'completed'
        when next_status = 'cancelled' then 'cancelled'
        else 'active'
      end
  where id = p_job_id
  returning * into current_job;

  insert into public.job_status_events (job_id, actor_id, status, note, eta_at)
  values (
    p_job_id,
    actor,
    next_status,
    nullif(trim(coalesce(p_note, '')), ''),
    current_job.eta_at
  );

  if next_status = 'completed' and current_job.accepted_bid_id is not null then
    perform public.sync_wallet_transaction_for_bid(current_job.accepted_bid_id, 'completed');
  end if;
  return current_job;
end;
$$;

revoke all on function public.update_job_progress(uuid, text, timestamptz, text)
from public, anon;
grant execute on function public.update_job_progress(uuid, text, timestamptz, text)
to authenticated;

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
        status = 'active',
        work_status = 'accepted',
        status_updated_at = timezone('utc', now())
    where id = new.job_id;

    perform public.sync_wallet_transaction_for_bid(new.id, 'accepted');

    insert into public.job_status_events (job_id, actor_id, status, note)
    values (new.job_id, owner_id, 'accepted', 'Bid accepted');

    insert into public.admin_notifications (
      type, title, body, actor_id, related_user_id, related_table, related_id
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

update public.wallet_transactions wt
set work_status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = wt.job_id
      ) then 'completed'
      else 'accepted'
    end,
    completed_at = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = wt.job_id
      ) then wt.completed_at
      else null
    end
where wt.event_type = 'bid_accepted';

update public.jobs j
set work_status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then 'completed'
      else 'accepted'
    end,
    status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then 'completed'
      else 'active'
    end,
    completed_at = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then coalesce(j.completed_at, wt.completed_at)
      else null
    end,
    status_updated_at = timezone('utc', now())
from public.wallet_transactions wt
where wt.job_id = j.id
  and wt.event_type = 'bid_accepted'
  and wt.bid_id = j.accepted_bid_id;

insert into public.job_status_events (job_id, actor_id, status, note, eta_at, created_at)
select
  j.id,
  j.created_by,
  j.work_status,
  'Imported existing job status',
  j.eta_at,
  coalesce(j.status_updated_at, j.created_at, timezone('utc', now()))
from public.jobs j
where j.accepted_bid_id is not null
  and not exists (
    select 1 from public.job_status_events e where e.job_id = j.id
  );
