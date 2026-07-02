-- Repair user-facing deletion flows:
-- - account deletion must not be blocked by locked job delete triggers
-- - per-user chat deletion must survive app reinstall
-- - notification delete needs the matching table grant

grant usage on schema public to authenticated;
grant delete on public.admin_notifications to authenticated;

create table if not exists public.user_thread_deletions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  thread_id uuid not null references public.threads(id) on delete cascade,
  deleted_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, thread_id)
);

alter table public.user_thread_deletions enable row level security;

grant select, insert, update, delete on public.user_thread_deletions
to authenticated;

drop policy if exists "Users can read own thread deletions"
on public.user_thread_deletions;
create policy "Users can read own thread deletions"
on public.user_thread_deletions
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can create own thread deletions"
on public.user_thread_deletions;
create policy "Users can create own thread deletions"
on public.user_thread_deletions
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (
        t.user_id = (select auth.uid())
        or t.artisan_id = (select auth.uid())
      )
  )
);

drop policy if exists "Users can update own thread deletions"
on public.user_thread_deletions;
create policy "Users can update own thread deletions"
on public.user_thread_deletions
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Users can delete own thread deletions"
on public.user_thread_deletions;
create policy "Users can delete own thread deletions"
on public.user_thread_deletions
for delete
to authenticated
using (user_id = (select auth.uid()));

create or replace function public.delete_thread_for_current_user(
  p_thread_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.threads t
    where t.id = p_thread_id
      and (
        t.user_id = (select auth.uid())
        or t.artisan_id = (select auth.uid())
      )
  ) then
    raise exception 'Chat not found';
  end if;

  insert into public.user_thread_deletions (user_id, thread_id, deleted_at)
  values ((select auth.uid()), p_thread_id, timezone('utc', now()))
  on conflict (user_id, thread_id)
  do update set deleted_at = excluded.deleted_at;
end;
$$;

revoke all on function public.delete_thread_for_current_user(uuid)
from public, anon;
grant execute on function public.delete_thread_for_current_user(uuid)
to authenticated;

drop policy if exists "Users can read own threads" on public.threads;
drop policy if exists "Users can manage own threads" on public.threads;
drop policy if exists "Users can create own threads" on public.threads;
drop policy if exists "Users can update own threads" on public.threads;
drop policy if exists "Users can delete own threads" on public.threads;
create policy "Users can read own threads"
on public.threads
for select
to authenticated
using (
  (
    (select auth.uid()) = user_id
    or (select auth.uid()) = artisan_id
  )
  and not exists (
    select 1
    from public.user_thread_deletions d
    where d.thread_id = threads.id
      and d.user_id = (select auth.uid())
  )
);

create policy "Users can create own threads"
on public.threads
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  or (select auth.uid()) = artisan_id
);

create policy "Users can update own threads"
on public.threads
for update
to authenticated
using (
  (select auth.uid()) = user_id
  or (select auth.uid()) = artisan_id
)
with check (
  (select auth.uid()) = user_id
  or (select auth.uid()) = artisan_id
);

create policy "Users can delete own threads"
on public.threads
for delete
to authenticated
using (
  (select auth.uid()) = user_id
  or (select auth.uid()) = artisan_id
);

drop policy if exists "Users can read thread messages" on public.messages;
create policy "Users can read thread messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (
        t.user_id = (select auth.uid())
        or t.artisan_id = (select auth.uid())
      )
      and not exists (
        select 1
        from public.user_thread_deletions d
        where d.thread_id = t.id
          and d.user_id = (select auth.uid())
      )
  )
);

do $$
declare
  constraint_name text;
begin
  select c.conname
  into constraint_name
  from pg_constraint c
  join pg_class r on r.oid = c.conrelid
  join pg_namespace n on n.oid = r.relnamespace
  where n.nspname = 'public'
    and r.relname = 'jobs'
    and c.contype = 'f'
    and pg_get_constraintdef(c.oid) like '%FOREIGN KEY (created_by)%';

  if constraint_name is not null then
    execute format('alter table public.jobs drop constraint %I', constraint_name);
  end if;
end;
$$;

alter table public.jobs drop constraint if exists jobs_created_by_fkey;
alter table public.jobs
  alter column created_by drop not null,
  add constraint jobs_created_by_fkey
  foreign key (created_by)
  references public.profiles(id)
  on delete set null;

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.jobs
  set created_by = null
  where created_by = current_user_id
    and (
      accepted_bid_id is not null
      or accepted_amount is not null
      or coalesce(work_status, 'open') <> 'open'
      or coalesce(status, 'open') in ('active', 'completed')
    );

  delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_current_user() from public, anon;
grant execute on function public.delete_current_user() to authenticated;
