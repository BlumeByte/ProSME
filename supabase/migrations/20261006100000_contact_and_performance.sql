-- Contact details for accepted jobs, plus database performance fixes.
--
-- 1. get_accepted_contact: the only way a customer and an accepted artisan can
--    read each other's phone number. It checks an accepted bid exists and that
--    the caller is one of the two parties, so phone numbers are not exposed to
--    anyone else and the table itself does not need to be opened up.
-- 2. Covering indexes for foreign keys the advisor flagged as unindexed.
-- 3. auth.uid()/auth.role()/auth.jwt()/auth.email() wrapped in (select ...) in
--    RLS policies so Postgres evaluates them once per statement, not per row.
-- 4. A partial index for the unread notification badge on the home screen.
-- 5. Drop identical duplicate indexes on the kv_store stub table.

create or replace function public.get_accepted_contact(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  j public.jobs%rowtype;
  b public.job_bids%rowtype;
  other_id uuid;
  result jsonb;
begin
  if caller is null then
    raise exception 'Sign in to view contact details.' using errcode = '42501';
  end if;

  select * into j from public.jobs where id = p_job_id;
  if not found then
    return null;
  end if;

  select * into b
  from public.job_bids
  where job_id = p_job_id and status = 'accepted'
  limit 1;
  if not found then
    return null;
  end if;

  if caller = j.created_by then
    other_id := b.artisan_id;
  elsif caller = b.artisan_id then
    other_id := j.created_by;
  else
    raise exception 'Contact details are only shared between the two parties on an accepted job.'
      using errcode = '42501';
  end if;

  -- Contact stays available only while the work is live, matching chat.
  if j.status = 'completed' or j.work_status = 'completed' then
    return null;
  end if;

  select jsonb_build_object(
    'user_id', p.id,
    'name', coalesce(nullif(p.username, ''), nullif(p.full_name, ''), 'Customer'),
    'phone', coalesce(p.phone, ''),
    'country', coalesce(p.country, ''),
    'country_code', coalesce(p.country_code, '')
  )
  into result
  from public.profiles p
  where p.id = other_id;

  return result;
end;
$$;

revoke all on function public.get_accepted_contact(uuid) from public, anon;
grant execute on function public.get_accepted_contact(uuid) to authenticated;

-- Covering indexes for unindexed foreign keys.
do $$
declare
  r record;
  idx_name text;
  cols text;
begin
  for r in
    select c.conname, c.conrelid, c.conkey, cl.relname as tbl
    from pg_constraint c
    join pg_class cl on cl.oid = c.conrelid
    join pg_namespace n on n.oid = cl.relnamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = c.conrelid
          and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey
      )
  loop
    select string_agg(quote_ident(a.attname), ', ' order by k.ord)
      into cols
      from unnest(r.conkey) with ordinality as k(attnum, ord)
      join pg_attribute a on a.attrelid = r.conrelid and a.attnum = k.attnum;
    idx_name := left('fk_' || r.tbl || '_' || r.conname, 58) || '_idx';
    execute format('create index if not exists %I on public.%I (%s)', idx_name, r.tbl, cols);
  end loop;
end;
$$;

-- Wrap bare auth.* calls in RLS policies with (select ...). Policies that
-- already use the wrapped form are left alone.
do $$
declare
  p record;
  fn text;
  q text;
  c text;
  clause text;
begin
  for p in
    select policyname, tablename, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        coalesce(qual, '') ~ 'auth\.(uid|role|jwt|email)\(\)'
        or coalesce(with_check, '') ~ 'auth\.(uid|role|jwt|email)\(\)'
      )
      and coalesce(qual, '') !~* 'select\s+auth\.'
      and coalesce(with_check, '') !~* 'select\s+auth\.'
  loop
    q := p.qual;
    c := p.with_check;
    foreach fn in array array['uid()', 'role()', 'jwt()', 'email()'] loop
      if q is not null then
        q := replace(q, 'auth.' || fn, '(select auth.' || fn || ')');
      end if;
      if c is not null then
        c := replace(c, 'auth.' || fn, '(select auth.' || fn || ')');
      end if;
    end loop;

    clause := '';
    if p.qual is not null then
      clause := clause || ' using (' || q || ')';
    end if;
    if p.with_check is not null then
      clause := clause || ' with check (' || c || ')';
    end if;
    execute format('alter policy %I on public.%I%s', p.policyname, p.tablename, clause);
  end loop;
end;
$$;

create index if not exists admin_notifications_related_unread_idx
  on public.admin_notifications (related_user_id)
  where read_at is null;

drop index if exists public.kv_store_8e58d1ea_key_idx1;
drop index if exists public.kv_store_8e58d1ea_key_idx2;
drop index if exists public.kv_store_8e58d1ea_key_idx3;
