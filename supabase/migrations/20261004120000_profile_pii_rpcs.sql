-- Profile PII, part 1 (safe to apply before clients are updated).
--
-- Today every signed-in user can read every other user's e-mail, phone, date
-- of birth, gender, mobile-money number and verification documents straight
-- from `profiles` (the `Public can read profiles` policy is `true` and the
-- table grants cover all columns). The fix is column-level privileges, but
-- the shipped clients select those columns directly, so the lock-down
-- (20261004130000_profile_pii_lockdown.sql) must wait until clients use the
-- RPCs below. These functions are additive and do not change behaviour yet.

-- The caller's own full profile row.
create or replace function public.get_my_profile()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(p) from public.profiles p where p.id = (select auth.uid());
$$;
revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- Every profile, all columns -- admin dashboards only.
create or replace function public.admin_list_profiles()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app_private.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;
  return query
    select to_jsonb(p) from public.profiles p order by p.created_at desc;
end;
$$;
revoke all on function public.admin_list_profiles() from public, anon;
grant execute on function public.admin_list_profiles() to authenticated;

-- The marketplace feed read profiles.email (as the caller) only to build a
-- display-name fallback. Run it as definer so it keeps working once the e-mail
-- column is no longer readable by clients, and stop deriving the public
-- display name from the e-mail address.
create or replace function public.get_listing_feed(p_limit integer default 100)
returns table(
  id uuid, artisan_id uuid, artisan_name text, artisan_photo_url text,
  artisan_busy boolean, title text, description text, category text,
  price_min numeric, price_max numeric, images text[], location text,
  verified_only boolean, created_at timestamp with time zone,
  rating_average numeric, rating_count bigint, won_bid_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with page as materialized (
    select l.*
    from public.listings l
    order by l.created_at desc, l.id desc
    limit least(greatest(coalesce(p_limit, 100), 1), 100)
  ),
  ratings as (
    select
      r.artisan_id,
      avg(r.stars)::numeric as rating_average,
      count(*)::bigint as rating_count
    from public.job_ratings r
    where r.artisan_id in (select distinct p.artisan_id from page p)
    group by r.artisan_id
  ),
  won_bids as (
    select b.artisan_id, count(*)::bigint as won_bid_count
    from public.job_bids b
    where b.status = 'accepted'
      and b.artisan_id in (select distinct p.artisan_id from page p)
    group by b.artisan_id
  )
  select
    p.id,
    p.artisan_id,
    coalesce(nullif(pr.full_name, ''), nullif(pr.username, ''), 'ProSME user') as artisan_name,
    coalesce(pr.avatar_url, '') as artisan_photo_url,
    coalesce(pr.is_busy, false) as artisan_busy,
    p.title,
    p.description,
    p.category,
    p.price_min,
    p.price_max,
    p.images,
    p.location,
    coalesce(pr.verification_status = 'verified', false) as verified_only,
    p.created_at,
    coalesce(r.rating_average, 0) as rating_average,
    coalesce(r.rating_count, 0) as rating_count,
    coalesce(w.won_bid_count, 0) as won_bid_count
  from page p
  join public.profiles pr on pr.id = p.artisan_id
  left join ratings r on r.artisan_id = p.artisan_id
  left join won_bids w on w.artisan_id = p.artisan_id
  order by p.created_at desc, p.id desc;
$$;
revoke all on function public.get_listing_feed(integer) from public, anon;
grant execute on function public.get_listing_feed(integer) to authenticated;
