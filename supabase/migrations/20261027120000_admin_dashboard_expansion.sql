-- Admin dashboard expansion: customer-care staff accounts, report
-- assignment (claim a ticket so it isn't answered twice), and a ratings
-- summary for the admin overview.

-- 1. Customer-care staff ----------------------------------------------------
-- A role='admin' account with staff_role='support' is a restricted staff
-- member: the app shows them only the Reports/Customer-care view instead of
-- the full dashboard (wallet resets, tenants, account deletion, ...). A
-- plain admin always has staff_role null. Harmless for a user to set on
-- their own row: it only ever matters together with role='admin', and
-- profiles_guard_write already pins `role` so nobody can self-escalate to
-- admin to make it apply.
alter table public.profiles
  add column if not exists staff_role text;

alter table public.profiles
  drop constraint if exists profiles_staff_role_check;
alter table public.profiles
  add constraint profiles_staff_role_check check (staff_role is null or staff_role = 'support');

-- 2. Report / ticket assignment ---------------------------------------------
-- Lets a customer-care agent "claim" an open report so two agents don't
-- answer the same ticket, and lets the queue be read oldest-unclaimed-first.
alter table public.reports
  add column if not exists assigned_to uuid references public.profiles(id) on delete set null;

create index if not exists reports_queue_idx
  on public.reports (status, assigned_to, created_at);

-- 3. Ratings summary for the admin overview ---------------------------------
create or replace function public.admin_ratings_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app_private.is_admin() then
    raise exception 'Only admins can view the ratings summary.' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'total', count(*),
      'average', coalesce(round(avg(stars)::numeric, 2), 0),
      'distribution', jsonb_build_object(
        '1', count(*) filter (where stars = 1),
        '2', count(*) filter (where stars = 2),
        '3', count(*) filter (where stars = 3),
        '4', count(*) filter (where stars = 4),
        '5', count(*) filter (where stars = 5)
      ),
      'top_artisans', coalesce((
        select jsonb_agg(t) from (
          select
            p.id,
            coalesce(nullif(p.username, ''), nullif(p.full_name, ''), 'Artisan') as name,
            round(avg(r.stars)::numeric, 2) as average,
            count(*) as total
          from public.job_ratings r
          join public.profiles p on p.id = r.artisan_id
          group by p.id, p.username, p.full_name
          order by avg(r.stars) desc, count(*) desc
          limit 10
        ) t
      ), '[]'::jsonb)
    )
    from public.job_ratings
  );
end;
$$;

revoke all on function public.admin_ratings_summary() from public, anon;
grant execute on function public.admin_ratings_summary() to authenticated;
