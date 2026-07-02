-- ProSME production data reset.
-- Destructive: removes app rows and Supabase Auth users.
-- Preserves schemas, tables, policies, functions, storage buckets, and migration history.
-- Storage objects must be removed with the Storage API; run:
--   node scripts/reset_production_storage.mjs
-- before or after this SQL if uploaded files also need to be cleared.

begin;

-- Clear every application table in public, including profiles, listings,
-- jobs, chats, notifications, reports, wallet history, billing records,
-- verification records, analytics, and reset ledgers.
do $$
declare
  table_names text;
begin
  select string_agg(format('%I.%I', schemaname, tablename), ', ')
  into table_names
  from pg_tables
  where schemaname = 'public';

  if table_names is not null then
    execute 'truncate table ' || table_names || ' restart identity cascade';
  end if;
end $$;

-- Clear Supabase Auth accounts. This removes user, artisan, and admin logins.
delete from auth.users;

commit;

-- Verification counts. All should be 0 after the reset.
select 'auth.users' as target, count(*) as rows_remaining from auth.users
union all
select 'storage.objects app buckets', count(*) from storage.objects
where bucket_id in ('avatars', 'listing-images', 'artisan-verification')
union all
select 'public.profiles', count(*) from public.profiles;
