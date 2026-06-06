alter table public.profiles
add column if not exists tenant_id text not null default 'default';

alter table public.listings
add column if not exists tenant_id text not null default 'default';

alter table public.jobs
add column if not exists tenant_id text not null default 'default',
add column if not exists status text not null default 'active'
  check (status in ('active', 'completed', 'cancelled'));

alter table public.profiles
drop constraint if exists profiles_role_check;

alter table public.profiles
add constraint profiles_role_check
check (role in ('customer', 'artisan', 'admin', 'developer'));

create table if not exists public.job_ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  unique (job_id, user_id)
);

alter table public.job_ratings enable row level security;

grant select, insert, update on public.job_ratings to authenticated;
grant select on public.admin_notifications to authenticated;
grant select on public.email_outbox to authenticated;

drop policy if exists "Users can read visible job ratings" on public.job_ratings;
create policy "Users can read visible job ratings"
on public.job_ratings for select
to authenticated
using (true);

drop policy if exists "Job owners can rate accepted artisans" on public.job_ratings;
create policy "Job owners can rate accepted artisans"
on public.job_ratings for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
  and exists (
    select 1
    from public.job_bids b
    where b.job_id = job_id
      and b.artisan_id = artisan_id
      and b.status = 'accepted'
  )
);

drop policy if exists "Job owners can update own ratings" on public.job_ratings;
create policy "Job owners can update own ratings"
on public.job_ratings for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Developers can update profiles" on public.profiles;
create policy "Developers can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
)
with check (true);

drop policy if exists "Developers can read admin notifications" on public.admin_notifications;
create policy "Developers can read admin notifications"
on public.admin_notifications for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

drop policy if exists "Developers can read email outbox" on public.email_outbox;
create policy "Developers can read email outbox"
on public.email_outbox for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
create policy "Job owners and bidders can read bids"
on public.job_bids for select
to authenticated
using (
  artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'developer')
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'job_ratings'
  ) then
    alter publication supabase_realtime add table public.job_ratings;
  end if;
end;
$$;
