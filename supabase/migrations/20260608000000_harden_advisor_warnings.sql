-- Harden Supabase advisor warnings while keeping REST access for signed-in app users.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from anon, authenticated;

drop policy if exists "Developers can update profiles" on public.profiles;
create policy "Developers can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'developer')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'developer')
  )
);

do $$
begin
  if to_regclass('public.job_applications') is not null then
    execute 'drop policy if exists "update applications" on public.job_applications';
  end if;
end;
$$;

drop policy if exists "Users can view verification documents" on storage.objects;
drop policy if exists "Public can view listing images" on storage.objects;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'admin_notifications',
    'applications',
    'email_outbox',
    'job_applications',
    'job_bids',
    'job_messages',
    'job_payments',
    'job_ratings',
    'job_reviews',
    'kv_store_8e58d1ea',
    'messages',
    'saved_listings',
    'threads'
  ]
  loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('revoke select on table public.%I from anon', table_name);
    end if;
  end loop;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'delete_current_user'
  ) then
    execute 'revoke execute on function public.delete_current_user() from anon';
    execute 'grant execute on function public.delete_current_user() to authenticated';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'rls_auto_enable'
  ) then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;
