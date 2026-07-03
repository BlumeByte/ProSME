alter table public.jobs
  add column if not exists request_type text not null default 'public',
  add column if not exists target_artisan_id uuid references public.profiles(id) on delete set null;

alter table public.jobs
  drop constraint if exists jobs_request_type_check,
  add constraint jobs_request_type_check
  check (request_type in ('public', 'direct'));

create index if not exists jobs_request_type_idx
on public.jobs (request_type);

create index if not exists jobs_target_artisan_id_idx
on public.jobs (target_artisan_id)
where target_artisan_id is not null;

alter table public.job_bids
  add column if not exists created_by_user_id uuid references public.profiles(id) on delete set null,
  add column if not exists counter_message text not null default '';

alter table public.job_bids
  drop constraint if exists job_bids_status_check,
  add constraint job_bids_status_check
  check (status in ('pending', 'edited', 'countered', 'accepted', 'rejected'));

grant select, insert, update, delete on public.jobs to authenticated;
grant select, insert, update on public.job_bids to authenticated;

drop policy if exists "Users can read jobs" on public.jobs;
drop policy if exists "Public can read jobs" on public.jobs;
drop policy if exists "read jobs" on public.jobs;
drop policy if exists "Authenticated users can read jobs" on public.jobs;
drop policy if exists "Users can read own jobs" on public.jobs;
drop policy if exists "Customers and artisans can read scoped jobs" on public.jobs;
create policy "Customers and artisans can read scoped jobs"
on public.jobs
for select
to authenticated
using (
  created_by = (select auth.uid())
  or app_private.is_admin()
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'artisan'
      and (
        jobs.request_type = 'public'
        or jobs.target_artisan_id = (select auth.uid())
        or exists (
          select 1
          from public.job_bids b
          where b.job_id = jobs.id
            and b.artisan_id = (select auth.uid())
        )
      )
  )
);

drop policy if exists "Users can create own jobs" on public.jobs;
create policy "Users can create own jobs"
on public.jobs
for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "Users can update own jobs" on public.jobs;
drop policy if exists "Users can update own open jobs" on public.jobs;
create policy "Users can update own open jobs"
on public.jobs
for update
to authenticated
using (
  created_by = (select auth.uid())
  and work_status = 'open'
  and accepted_bid_id is null
)
with check (
  created_by = (select auth.uid())
);

drop policy if exists "Users can delete own jobs" on public.jobs;
drop policy if exists "Users can delete own open jobs" on public.jobs;
create policy "Users can delete own open jobs"
on public.jobs
for delete
to authenticated
using (
  created_by = (select auth.uid())
  and work_status = 'open'
  and accepted_bid_id is null
);

drop policy if exists "Artisans can create own job bids" on public.job_bids;
drop policy if exists "Artisans and direct customers can create job bids" on public.job_bids;
create policy "Artisans and direct customers can create job bids"
on public.job_bids
for insert
to authenticated
with check (
  (
    artisan_id = (select auth.uid())
    and created_by_user_id is null
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'artisan'
    )
    and exists (
      select 1
      from public.jobs j
      where j.id = job_id
        and j.created_by is distinct from (select auth.uid())
        and j.request_type = 'public'
    )
  )
  or (
    created_by_user_id = (select auth.uid())
    and exists (
      select 1
      from public.jobs j
      where j.id = job_id
        and j.created_by = (select auth.uid())
        and j.request_type = 'direct'
        and j.target_artisan_id = artisan_id
    )
  )
);

drop policy if exists "Artisans can update own pending bids" on public.job_bids;
drop policy if exists "Job owners can accept bids" on public.job_bids;
drop policy if exists "Bid participants can update active bids" on public.job_bids;
create policy "Bid participants can update active bids"
on public.job_bids
for update
to authenticated
using (
  status in ('pending', 'edited', 'countered')
  and (
    artisan_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      where j.id = job_id and j.created_by = (select auth.uid())
    )
    or app_private.is_admin()
  )
)
with check (
  (
    artisan_id = (select auth.uid())
    and status in ('pending', 'countered', 'accepted', 'rejected')
  )
  or (
    exists (
      select 1
      from public.jobs j
      where j.id = job_id and j.created_by = (select auth.uid())
    )
    and status in ('edited', 'accepted')
  )
  or app_private.is_admin()
);

create or replace function public.notify_job_bid_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  job_title_value text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  select created_by, title
  into owner_id, job_title_value
  from public.jobs
  where id = new.job_id;

  if new.status in ('countered', 'rejected') and owner_id is not null then
    insert into public.admin_notifications (
      type, title, body, actor_id, related_user_id, related_table, related_id
    ) values (
      'direct_bid_' || new.status,
      case when new.status = 'countered' then 'Direct bid countered' else 'Direct bid rejected' end,
      case
        when new.status = 'countered'
          then 'The artisan countered your offer for "' || coalesce(job_title_value, 'your request') || '".'
        else 'The artisan rejected your offer for "' || coalesce(job_title_value, 'your request') || '". You can edit or delete the request.'
      end,
      new.artisan_id,
      owner_id,
      'job_bids',
      new.id
    );
  elsif new.status = 'edited' then
    insert into public.admin_notifications (
      type, title, body, actor_id, related_user_id, related_table, related_id
    ) values (
      'direct_bid_edited',
      'Direct bid edited',
      'The customer edited the offer for "' || coalesce(job_title_value, 'a request') || '".',
      owner_id,
      new.artisan_id,
      'job_bids',
      new.id
    );
  end if;

  return new;
end;
$$;

revoke all on function public.notify_job_bid_status()
from public, anon, authenticated;

drop trigger if exists job_bids_notify_status on public.job_bids;
create trigger job_bids_notify_status
after update of status on public.job_bids
for each row execute function public.notify_job_bid_status();
