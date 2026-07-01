-- Keep saved listings and foreground notifications reachable on projects where
-- public schema objects no longer receive implicit API grants.
grant usage on schema public to authenticated;

grant select, insert, delete on public.saved_listings to authenticated;
grant select, insert, update on public.admin_notifications to authenticated;

alter table public.saved_listings enable row level security;
alter table public.admin_notifications enable row level security;

drop policy if exists "Users can read own saved listings" on public.saved_listings;
create policy "Users can read own saved listings"
on public.saved_listings for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can save listings" on public.saved_listings;
create policy "Users can save listings"
on public.saved_listings for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can unsave listings" on public.saved_listings;
create policy "Users can unsave listings"
on public.saved_listings for delete
to authenticated
using ((select auth.uid()) = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'saved_listings'
  ) then
    alter publication supabase_realtime add table public.saved_listings;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'admin_notifications'
  ) then
    alter publication supabase_realtime add table public.admin_notifications;
  end if;
end;
$$;
