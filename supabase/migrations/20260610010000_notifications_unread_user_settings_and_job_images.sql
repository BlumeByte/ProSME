-- Add settings, unread tracking, and job image compatibility.

alter table public.profiles
add column if not exists username_updated_at timestamptz,
add column if not exists email_notifications boolean not null default true,
add column if not exists phone_notifications boolean not null default true,
add column if not exists app_language text not null default 'English';

alter table public.messages
add column if not exists read_at timestamptz;

alter table public.jobs
add column if not exists images text[] not null default '{}';

grant select, insert, update on public.messages to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;

drop policy if exists "Thread participants can mark messages read" on public.messages;
create policy "Thread participants can mark messages read"
on public.messages for update
to authenticated
using (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = (select auth.uid()) or t.artisan_id = (select auth.uid()))
  )
)
with check (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = (select auth.uid()) or t.artisan_id = (select auth.uid()))
  )
);

drop policy if exists "Users can update own jobs" on public.jobs;
create policy "Users can update own jobs"
on public.jobs for update
to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);
