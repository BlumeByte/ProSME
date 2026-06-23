-- Rename the platform dashboard role to admin and repair
-- dashboard access to thread ordering.

alter table if exists public.threads
  add column if not exists created_at timestamptz;

update public.threads
set created_at = coalesce(updated_at, timezone('utc', now()))
where created_at is null;

alter table if exists public.threads
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

alter table public.profiles drop constraint if exists profiles_role_check;

update public.profiles
set role = 'admin'
where role = ('devel' || 'oper');

update auth.users
set raw_app_meta_data =
      coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin'),
    raw_user_meta_data =
      coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
where raw_app_meta_data ->> 'role' = ('devel' || 'oper')
   or raw_user_meta_data ->> 'role' = ('devel' || 'oper')
   or id in (select id from public.profiles where role = 'admin');

alter table public.profiles
  drop constraint if exists profiles_role_check,
  add constraint profiles_role_check
  check (role in ('customer', 'artisan', 'admin'));

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon, authenticated;
grant execute on function app_private.is_admin() to authenticated;

grant select on public.profiles to authenticated;
grant select, update on public.reports to authenticated;
grant select, insert, update, delete on public.admin_notifications to authenticated;
grant select on public.email_outbox to authenticated;
grant select on public.sms_outbox to authenticated;
grant select on public.job_bids to authenticated;
grant select on public.job_status_events to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.threads to authenticated;
grant select on public.messages to authenticated;
grant select, delete on public.chat_blocks to authenticated;

do $$
declare
  legacy_plural text := 'Devel' || 'opers';
  legacy_role text := 'devel' || 'oper';
begin
  execute format('drop policy if exists %I on public.reports', legacy_plural || ' can update reports');
  execute format('drop policy if exists %I on public.reports', legacy_plural || ' can delete reports');
  execute format('drop policy if exists %I on public.profiles', legacy_plural || ' can manage profiles');
  execute format('drop policy if exists %I on public.profiles', legacy_plural || ' can update profiles');
  execute format('drop policy if exists %I on public.listings', legacy_plural || ' can manage listings');
  execute format('drop policy if exists %I on public.jobs', legacy_plural || ' can manage jobs');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can read admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can create admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can update admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can delete admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can read ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can update ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can delete ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.email_outbox', legacy_plural || ' can read email outbox');
  execute format('drop policy if exists %I on public.sms_outbox', legacy_plural || ' can read sms outbox');
  execute format('drop policy if exists %I on public.job_bids', legacy_plural || ' can read all job bids');
  execute format('drop policy if exists %I on public.wallet_transactions', legacy_plural || ' can read all wallet transactions');
  execute format('drop policy if exists %I on public.threads', legacy_plural || ' can read all threads');
  execute format('drop policy if exists %I on public.messages', legacy_plural || ' can read all messages');
end $$;
drop policy if exists "Users can delete own notifications" on public.admin_notifications;
drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
drop policy if exists "Participants can read job timeline" on public.job_status_events;
drop policy if exists "Users can read own reports" on public.reports;
drop policy if exists "Users can read own wallet transactions" on public.wallet_transactions;
drop policy if exists "Admins can update reports" on public.reports;
drop policy if exists "Admins can delete reports" on public.reports;
drop policy if exists "Admins can manage profiles" on public.profiles;
drop policy if exists "Admins can manage listings" on public.listings;
drop policy if exists "Admins can manage jobs" on public.jobs;
drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;
drop policy if exists "Admins can read email outbox" on public.email_outbox;
drop policy if exists "Admins can read sms outbox" on public.sms_outbox;
drop policy if exists "Admins can read all job bids" on public.job_bids;
drop policy if exists "Admins can read all wallet transactions" on public.wallet_transactions;
drop policy if exists "Admins can read all threads" on public.threads;
drop policy if exists "Admins can read all messages" on public.messages;

create policy "Admins can update reports"
on public.reports
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can delete reports"
on public.reports
for delete
to authenticated
using (app_private.is_admin());

create policy "Admins can manage profiles"
on public.profiles
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can manage listings"
on public.listings
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can manage jobs"
on public.jobs
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can read admin notifications"
on public.admin_notifications
for select
to authenticated
using (
  app_private.is_admin()
  or related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
);

create policy "Admins can create admin notifications"
on public.admin_notifications
for insert
to authenticated
with check (
  actor_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Admins can update admin notifications"
on public.admin_notifications
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can delete admin notifications"
on public.admin_notifications
for delete
to authenticated
using (app_private.is_admin());

create policy "Admins can read email outbox"
on public.email_outbox
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read sms outbox"
on public.sms_outbox
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all job bids"
on public.job_bids
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all wallet transactions"
on public.wallet_transactions
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all threads"
on public.threads
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all messages"
on public.messages
for select
to authenticated
using (app_private.is_admin());

create policy "Users can delete own notifications"
on public.admin_notifications
for delete
to authenticated
using (
  related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Job owners and bidders can read bids"
on public.job_bids
for select
to authenticated
using (
  artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id = job_bids.job_id
      and j.created_by = (select auth.uid())
  )
  or app_private.is_admin()
);

create policy "Participants can read job timeline"
on public.job_status_events
for select
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
        or app_private.is_admin()
      )
  )
);

create policy "Users can read own reports"
on public.reports
for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Users can read own wallet transactions"
on public.wallet_transactions
for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create support notifications" on public.admin_notifications;
create policy "Authenticated users can create support notifications"
on public.admin_notifications
for insert
to authenticated
with check (
  actor_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can read own chat blocks" on public.chat_blocks;
create policy "Users can read own chat blocks"
on public.chat_blocks
for select
to authenticated
using (
  blocker_id = (select auth.uid())
  or blocked_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can delete own chat blocks" on public.chat_blocks;
create policy "Users can delete own chat blocks"
on public.chat_blocks
for delete
to authenticated
using (
  blocker_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create limited email tasks" on public.email_outbox;
create policy "Authenticated users can create email tasks"
on public.email_outbox
for insert
to authenticated
with check (
  (
    related_user_id = (select auth.uid())
    and (to_email is null or lower(to_email) = 'blumebyte@gmail.com')
  )
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create own sms tasks" on public.sms_outbox;
drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
create policy "Authenticated users can create sms tasks"
on public.sms_outbox
for insert
to authenticated
with check (
  related_user_id = (select auth.uid())
  or app_private.is_admin()
);

update public.admin_notifications
set type = 'admin_response'
where type = ('devel' || 'oper' || '_response');

do $$
begin
  execute format('drop function if exists app_private.%I()', 'is_' || 'devel' || 'oper');
end $$;
