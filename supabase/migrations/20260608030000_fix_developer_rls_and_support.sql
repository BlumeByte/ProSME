-- Repair developer dashboard access, profile RLS recursion, and support tickets.

create extension if not exists "pgcrypto";
create schema if not exists app_private;

create or replace function app_private.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'developer'
  );
$$;

revoke all on function app_private.is_developer() from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_developer() to authenticated;

do $$
declare
  role_constraint record;
begin
  for role_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%role%'
  loop
    execute format('alter table public.profiles drop constraint if exists %I', role_constraint.conname);
  end loop;
end;
$$;

update public.profiles
set role = 'developer'
where role = 'admin';

update public.profiles
set role = 'developer',
    verification_status = 'verified',
    full_name = coalesce(nullif(full_name, ''), 'BlumeByte Developer'),
    email = coalesce(nullif(email, ''), 'blumebyte@gmail.com')
where lower(email) = 'blumebyte@gmail.com';

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('customer', 'artisan', 'developer'));

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  type text not null default 'support_ticket',
  category text,
  title text,
  body text,
  message text,
  status text not null default 'open',
  related_table text,
  related_id uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;
grant select, insert, update, delete on public.reports to authenticated;
revoke select, insert, update, delete on public.reports from anon;

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    alter table public.admin_notifications
      add column if not exists related_user_id uuid references public.profiles(id) on delete set null,
      add column if not exists related_table text,
      add column if not exists related_id uuid,
      add column if not exists read_at timestamptz;

    grant select, insert, update, delete on public.admin_notifications to authenticated;
    revoke select, insert, update, delete on public.admin_notifications from anon;
  end if;
end;
$$;

drop policy if exists "Users can create reports" on public.reports;
create policy "Users can create reports"
on public.reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

drop policy if exists "Users can read related reports" on public.reports;
create policy "Users can read related reports"
on public.reports for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_developer()
);

drop policy if exists "Developers can update reports" on public.reports;
create policy "Developers can update reports"
on public.reports for update
to authenticated
using (app_private.is_developer())
with check (app_private.is_developer());

drop policy if exists "Developers can delete reports" on public.reports;
create policy "Developers can delete reports"
on public.reports for delete
to authenticated
using (app_private.is_developer());

drop policy if exists "Developers can update profiles" on public.profiles;
drop policy if exists "Developers can manage profiles" on public.profiles;
create policy "Developers can manage profiles"
on public.profiles for all
to authenticated
using (app_private.is_developer())
with check (app_private.is_developer());

drop policy if exists "Developers can manage listings" on public.listings;
create policy "Developers can manage listings"
on public.listings for all
to authenticated
using (app_private.is_developer())
with check (app_private.is_developer());

drop policy if exists "Developers can manage jobs" on public.jobs;
create policy "Developers can manage jobs"
on public.jobs for all
to authenticated
using (app_private.is_developer())
with check (app_private.is_developer());

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    drop policy if exists "Admins can read notifications" on public.admin_notifications;
    drop policy if exists "Developers can read admin notifications" on public.admin_notifications;
    drop policy if exists "Developers can create admin notifications" on public.admin_notifications;
    drop policy if exists "Developers can update admin notifications" on public.admin_notifications;
    drop policy if exists "Developers can delete admin notifications" on public.admin_notifications;
    drop policy if exists "Developers can read developer notifications" on public.admin_notifications;
    drop policy if exists "Authenticated users can create support notifications" on public.admin_notifications;
    drop policy if exists "Developers can update developer notifications" on public.admin_notifications;
    drop policy if exists "Developers can delete developer notifications" on public.admin_notifications;

    create policy "Developers can read developer notifications"
    on public.admin_notifications for select
    to authenticated
    using (
      app_private.is_developer()
      or related_user_id = (select auth.uid())
      or actor_id = (select auth.uid())
    );

    create policy "Authenticated users can create support notifications"
    on public.admin_notifications for insert
    to authenticated
    with check (
      actor_id = (select auth.uid())
      or app_private.is_developer()
    );

    create policy "Developers can update developer notifications"
    on public.admin_notifications for update
    to authenticated
    using (app_private.is_developer())
    with check (app_private.is_developer());

    create policy "Developers can delete developer notifications"
    on public.admin_notifications for delete
    to authenticated
    using (app_private.is_developer());
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.email_outbox') is not null then
    drop policy if exists "Admins can read email tasks" on public.email_outbox;
    drop policy if exists "Developers can read email outbox" on public.email_outbox;

    create policy "Developers can read email outbox"
    on public.email_outbox for select
    to authenticated
    using (app_private.is_developer());
  end if;
end;
$$;
