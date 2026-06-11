alter table public.profiles
add column if not exists is_busy boolean not null default false;

grant select, update on public.profiles to authenticated;

grant select, update on public.admin_notifications to authenticated;

drop policy if exists "Users can read own notifications" on public.admin_notifications;
create policy "Users can read own notifications"
on public.admin_notifications for select
to authenticated
using (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()));

drop policy if exists "Users can mark own notifications read" on public.admin_notifications;
create policy "Users can mark own notifications read"
on public.admin_notifications for update
to authenticated
using (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()))
with check (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()));
