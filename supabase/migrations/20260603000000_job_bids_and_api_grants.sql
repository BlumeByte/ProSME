-- Make app API access explicit for new Supabase projects and add job bids.
grant usage on schema public to anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant select on public.listings to anon, authenticated;
grant insert, update, delete on public.listings to authenticated;
grant select, insert on public.jobs to anon, authenticated;
grant update, delete on public.jobs to authenticated;
grant select, insert, update on public.threads to authenticated;
grant select, insert on public.messages to authenticated;

create table if not exists public.job_bids (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  message text not null default '',
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (job_id, artisan_id)
);

alter table public.job_bids enable row level security;

drop trigger if exists job_bids_set_updated_at on public.job_bids;
create trigger job_bids_set_updated_at
before update on public.job_bids
for each row execute function public.set_updated_at();

grant select, insert, update on public.job_bids to authenticated;

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
    where p.id = (select auth.uid()) and p.role = 'admin'
  )
);

drop policy if exists "Artisans can create own job bids" on public.job_bids;
create policy "Artisans can create own job bids"
on public.job_bids for insert
to authenticated
with check (
  artisan_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'artisan'
  )
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by <> (select auth.uid())
  )
);

drop policy if exists "Artisans can update own pending bids" on public.job_bids;
create policy "Artisans can update own pending bids"
on public.job_bids for update
to authenticated
using (artisan_id = (select auth.uid()) and status = 'pending')
with check (artisan_id = (select auth.uid()) and status = 'pending');

drop policy if exists "Job owners can accept bids" on public.job_bids;
create policy "Job owners can accept bids"
on public.job_bids for update
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'job_bids'
  ) then
    alter publication supabase_realtime add table public.job_bids;
  end if;
end;
$$;
