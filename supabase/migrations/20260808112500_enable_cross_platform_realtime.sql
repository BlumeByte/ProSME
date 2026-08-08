-- ProSME cross-platform realtime publication
-- Keeps web and mobile views synchronized through the same Supabase project.

begin;

-- Add core user-facing tables to the Supabase Realtime publication when they
-- are not already present. The guards make this migration safe to re-run.
do $$
declare
  table_name text;
  realtime_tables text[] := array[
    'profiles',
    'listings',
    'jobs',
    'job_bids',
    'threads',
    'messages',
    'job_ratings',
    'admin_notifications',
    'wallet_transactions',
    'verification_subscriptions',
    'reports'
  ];
begin
  foreach table_name in array realtime_tables loop
    if to_regclass(format('public.%I', table_name)) is not null
       and not exists (
         select 1
         from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = table_name
       ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end $$;

-- FULL replica identity makes UPDATE/DELETE events reliable for clients that
-- filter streams using columns other than the primary key.
do $$
declare
  table_name text;
  realtime_tables text[] := array[
    'profiles',
    'listings',
    'jobs',
    'job_bids',
    'threads',
    'messages',
    'job_ratings',
    'admin_notifications',
    'wallet_transactions',
    'verification_subscriptions',
    'reports'
  ];
begin
  foreach table_name in array realtime_tables loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('alter table public.%I replica identity full', table_name);
    end if;
  end loop;
end $$;

commit;
