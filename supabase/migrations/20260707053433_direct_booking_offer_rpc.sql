create or replace function public.create_direct_booking_offer(
  p_artisan_id uuid,
  p_title text,
  p_description text,
  p_location text,
  p_amount numeric,
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  job_row public.jobs%rowtype;
  bid_row public.job_bids%rowtype;
begin
  if actor_id is null then
    raise exception 'Sign in required.';
  end if;

  if p_artisan_id is null then
    raise exception 'Artisan is required.';
  end if;

  if p_artisan_id = actor_id then
    raise exception 'You cannot send a booking offer to yourself.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Offer amount must be greater than zero.';
  end if;

  if nullif(trim(coalesce(p_title, '')), '') is null then
    raise exception 'Booking title is required.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_artisan_id
      and p.role = 'artisan'
  ) then
    raise exception 'Artisan account not found.';
  end if;

  insert into public.jobs (
    title,
    description,
    location,
    budget,
    created_by,
    status,
    work_status,
    request_type,
    target_artisan_id
  )
  values (
    trim(p_title),
    coalesce(p_description, ''),
    coalesce(p_location, ''),
    p_amount,
    actor_id,
    'open',
    'open',
    'direct',
    p_artisan_id
  )
  returning * into job_row;

  insert into public.job_bids (
    job_id,
    artisan_id,
    amount,
    message,
    status,
    created_by_user_id
  )
  values (
    job_row.id,
    p_artisan_id,
    p_amount,
    coalesce(p_message, ''),
    'pending',
    actor_id
  )
  returning * into bid_row;

  return jsonb_build_object(
    'job',
    to_jsonb(job_row),
    'bid',
    to_jsonb(bid_row)
  );
end;
$$;

revoke all on function public.create_direct_booking_offer(uuid, text, text, text, numeric, text)
from public, anon, authenticated;

grant execute on function public.create_direct_booking_offer(uuid, text, text, text, numeric, text)
to authenticated;
