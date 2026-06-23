-- Admin web dashboard management support.
-- Apply this in Supabase before deploying the updated admin dashboard.

create extension if not exists "pgcrypto";

create schema if not exists app_private;

create or replace function app_private.is_admin()
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
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_admin() to authenticated;

update public.profiles
set role = 'admin',
    verification_status = 'verified',
    full_name = coalesce(nullif(full_name, ''), 'BlumeByte Admin'),
    email = coalesce(nullif(email, ''), 'blumebyte@gmail.com')
where lower(email) = 'blumebyte@gmail.com';

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  related_table text,
  related_id uuid,
  type text not null default 'report',
  category text not null default 'general',
  title text,
  body text not null default '',
  description text not null default '',
  message text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    alter table public.admin_notifications
    add column if not exists related_user_id uuid references public.profiles(id) on delete set null,
    add column if not exists related_table text,
    add column if not exists related_id uuid;
  end if;
end;
$$;

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

alter table public.reports enable row level security;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;
grant select, insert, update, delete on public.reports to authenticated;

revoke select, insert, update, delete on public.reports from anon;

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    grant select, insert, update, delete on public.admin_notifications to authenticated;
  end if;
end;
$$;

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports"
on public.reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

drop policy if exists "Users can read own reports" on public.reports;
create policy "Users can read own reports"
on public.reports for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
on public.reports for update
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can delete reports" on public.reports;
create policy "Admins can delete reports"
on public.reports for delete
to authenticated
using (
  app_private.is_admin()
);

drop policy if exists "Admins can update profiles" on public.profiles;
drop policy if exists "Admins can manage profiles" on public.profiles;
create policy "Admins can manage profiles"
on public.profiles for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can manage listings" on public.listings;
create policy "Admins can manage listings"
on public.listings for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can manage jobs" on public.jobs;
create policy "Admins can manage jobs"
on public.jobs for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    drop policy if exists "Admins can read notifications" on public.admin_notifications;
    drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
    create policy "Admins can read admin notifications"
    on public.admin_notifications for select
    to authenticated
    using (app_private.is_admin());

    create policy "Admins can create admin notifications"
    on public.admin_notifications for insert
    to authenticated
    with check (
      actor_id = (select auth.uid())
      and app_private.is_admin()
    );

    drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
    create policy "Admins can update admin notifications"
    on public.admin_notifications for update
    to authenticated
    using (app_private.is_admin())
    with check (app_private.is_admin());

    drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;
    create policy "Admins can delete admin notifications"
    on public.admin_notifications for delete
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.email_outbox') is not null then
    drop policy if exists "Admins can read email tasks" on public.email_outbox;
    drop policy if exists "Admins can read email outbox" on public.email_outbox;
    create policy "Admins can read email outbox"
    on public.email_outbox for select
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reports'
  ) then
    alter publication supabase_realtime add table public.reports;
  end if;
end;
$$;
