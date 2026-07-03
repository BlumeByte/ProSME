create schema if not exists app_private;

create or replace function app_private.profile_role(check_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = check_user_id
  limit 1;
$$;

create or replace function app_private.is_job_owner(
  check_job_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs j
    where j.id = check_job_id
      and j.created_by = check_user_id
  );
$$;

create or replace function app_private.can_read_job(
  check_job_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs j
    where j.id = check_job_id
      and (
        j.created_by = check_user_id
        or app_private.is_admin()
        or (
          app_private.profile_role(check_user_id) = 'artisan'
          and (
            j.request_type = 'public'
            or j.target_artisan_id = check_user_id
            or exists (
              select 1
              from public.job_bids b
              where b.job_id = j.id
                and b.artisan_id = check_user_id
            )
          )
        )
      )
  );
$$;

create or replace function app_private.can_create_job_bid(
  check_job_id uuid,
  check_artisan_id uuid,
  check_created_by_user_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs j
    where j.id = check_job_id
      and (
        (
          check_artisan_id = check_user_id
          and check_created_by_user_id is null
          and app_private.profile_role(check_user_id) = 'artisan'
          and j.created_by is distinct from check_user_id
          and j.request_type = 'public'
        )
        or (
          check_created_by_user_id = check_user_id
          and j.created_by = check_user_id
          and j.request_type = 'direct'
          and j.target_artisan_id = check_artisan_id
        )
      )
  );
$$;

create or replace function app_private.can_update_job_bid(
  check_job_id uuid,
  check_artisan_id uuid,
  check_status text,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
    app_private.is_admin()
    or (
      check_artisan_id = check_user_id
      and check_status in ('pending', 'countered', 'accepted', 'rejected')
    )
    or (
      app_private.is_job_owner(check_job_id, check_user_id)
      and check_status in ('edited', 'accepted')
    )
  );
$$;

create or replace function app_private.can_read_job_bid(
  check_job_id uuid,
  check_artisan_id uuid,
  check_created_by_user_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
    app_private.is_admin()
    or check_artisan_id = check_user_id
    or check_created_by_user_id = check_user_id
    or app_private.is_job_owner(check_job_id, check_user_id)
  );
$$;

revoke all on function app_private.profile_role(uuid) from public, anon, authenticated;
revoke all on function app_private.is_job_owner(uuid, uuid) from public, anon, authenticated;
revoke all on function app_private.can_read_job(uuid, uuid) from public, anon, authenticated;
revoke all on function app_private.can_create_job_bid(uuid, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function app_private.can_update_job_bid(uuid, uuid, text, uuid) from public, anon, authenticated;
revoke all on function app_private.can_read_job_bid(uuid, uuid, uuid, uuid) from public, anon, authenticated;

grant usage on schema app_private to authenticated;
grant execute on function app_private.profile_role(uuid) to authenticated;
grant execute on function app_private.is_job_owner(uuid, uuid) to authenticated;
grant execute on function app_private.can_read_job(uuid, uuid) to authenticated;
grant execute on function app_private.can_create_job_bid(uuid, uuid, uuid, uuid) to authenticated;
grant execute on function app_private.can_update_job_bid(uuid, uuid, text, uuid) to authenticated;
grant execute on function app_private.can_read_job_bid(uuid, uuid, uuid, uuid) to authenticated;

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
using (app_private.can_read_job(id, (select auth.uid())));

drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
create policy "Job owners and bidders can read bids"
on public.job_bids
for select
to authenticated
using (
  app_private.can_read_job_bid(
    job_id,
    artisan_id,
    created_by_user_id,
    (select auth.uid())
  )
);

drop policy if exists "Artisans can create own job bids" on public.job_bids;
drop policy if exists "Artisans and direct customers can create job bids" on public.job_bids;
create policy "Artisans and direct customers can create job bids"
on public.job_bids
for insert
to authenticated
with check (
  app_private.can_create_job_bid(
    job_id,
    artisan_id,
    created_by_user_id,
    (select auth.uid())
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
    or app_private.is_job_owner(job_id, (select auth.uid()))
    or app_private.is_admin()
  )
)
with check (
  app_private.can_update_job_bid(
    job_id,
    artisan_id,
    status,
    (select auth.uid())
  )
);
