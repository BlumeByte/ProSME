-- Scale the ProSME read and realtime hot paths without changing product data.

-- Feed, chat, notification, and foreign-key lookups used by the mobile app.
create index if not exists listings_created_id_idx
  on public.listings (created_at desc, id desc);
create index if not exists listings_artisan_id_idx
  on public.listings (artisan_id);

create index if not exists threads_user_updated_idx
  on public.threads (user_id, updated_at desc);
create index if not exists threads_artisan_updated_idx
  on public.threads (artisan_id, updated_at desc);

create index if not exists messages_thread_created_idx
  on public.messages (thread_id, created_at desc, id);
create index if not exists messages_sender_id_idx
  on public.messages (sender_id);
create index if not exists messages_unread_thread_sender_idx
  on public.messages (thread_id, sender_id)
  where read_at is null;

create index if not exists saved_listings_listing_id_idx
  on public.saved_listings (listing_id);
create index if not exists job_ratings_artisan_id_idx
  on public.job_ratings (artisan_id);
create index if not exists job_ratings_user_id_idx
  on public.job_ratings (user_id);
create index if not exists admin_notifications_user_created_idx
  on public.admin_notifications (related_user_id, created_at desc);
create index if not exists admin_notifications_actor_id_idx
  on public.admin_notifications (actor_id);

-- One bounded database request replaces four client round trips and prevents
-- the home feed from downloading an unbounded number of rows.
create or replace function public.get_listing_feed(p_limit integer default 100)
returns table (
  id uuid,
  artisan_id uuid,
  artisan_name text,
  artisan_photo_url text,
  artisan_busy boolean,
  title text,
  description text,
  category text,
  price_min numeric,
  price_max numeric,
  images text[],
  location text,
  verified_only boolean,
  created_at timestamptz,
  rating_average numeric,
  rating_count bigint,
  won_bid_count bigint
)
language sql
stable
security invoker
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
    coalesce(nullif(pr.full_name, ''), nullif(pr.username, ''),
      split_part(coalesce(pr.email, ''), '@', 1)) as artisan_name,
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

-- Count unread messages in Postgres rather than returning every unread row to
-- each phone. RLS still limits callers to conversations they can access.
create or replace function public.get_unread_thread_counts(p_thread_ids uuid[])
returns table (thread_id uuid, unread_count bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select m.thread_id, count(*)::bigint
  from public.messages m
  where m.thread_id = any(coalesce(p_thread_ids, '{}'::uuid[]))
    and m.sender_id <> (select auth.uid())
    and m.read_at is null
  group by m.thread_id;
$$;

revoke all on function public.get_unread_thread_counts(uuid[]) from public, anon;
grant execute on function public.get_unread_thread_counts(uuid[]) to authenticated;

-- Remove legacy duplicate policies and make auth.uid() an init-plan so it is
-- evaluated once per query instead of once per row.
drop policy if exists "Users can manage own threads" on public.threads;
drop policy if exists "Users can read own threads" on public.threads;
create policy "Users can read own threads"
on public.threads for select to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
);

drop policy if exists "read messages" on public.messages;
drop policy if exists "send message" on public.messages;
drop policy if exists "Users can read thread messages" on public.messages;
create policy "Users can read thread messages"
on public.messages for select to authenticated
using (
  exists (
    select 1
    from public.threads t
    where t.id = messages.thread_id
      and (
        t.user_id = (select auth.uid())
        or t.artisan_id = (select auth.uid())
      )
  )
);

drop policy if exists "Users can send thread messages" on public.messages;
create policy "Users can send thread messages"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1
    from public.threads t
    where t.id = messages.thread_id
      and (
        t.user_id = (select auth.uid())
        or t.artisan_id = (select auth.uid())
      )
  )
);

drop policy if exists "Users can read own saved listings" on public.saved_listings;
create policy "Users can read own saved listings"
on public.saved_listings for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can save listings" on public.saved_listings;
create policy "Users can save listings"
on public.saved_listings for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can unsave listings" on public.saved_listings;
create policy "Users can unsave listings"
on public.saved_listings for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can read listings" on public.listings;
drop policy if exists "Users can read jobs" on public.jobs;
drop policy if exists "create jobs" on public.jobs;
drop policy if exists "delete own jobs" on public.jobs;
drop policy if exists "update own jobs" on public.jobs;
drop policy if exists "Authenticated users can create notifications"
  on public.admin_notifications;
drop policy if exists "Authenticated users can create support notifications"
  on public.admin_notifications;
drop policy if exists "Users can read own notifications"
  on public.admin_notifications;

-- Broadcast authorizes a private channel once when it is joined. Unlike
-- Postgres Changes, it does not run one RLS check per subscriber per row.
drop policy if exists "ProSME users can receive scoped broadcasts"
  on realtime.messages;
create policy "ProSME users can receive scoped broadcasts"
on realtime.messages for select to authenticated
using (
  extension = 'broadcast'
  and (
    (select realtime.topic()) =
      ('prosme:user:' || (select auth.uid())::text)
    or exists (
      select 1
      from public.threads t
      where (select realtime.topic()) =
          ('prosme:thread:' || t.id::text)
        and (
          t.user_id = (select auth.uid())
          or t.artisan_id = (select auth.uid())
        )
    )
  )
);

create or replace function app_private.broadcast_prosme_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.related_user_id is not null then
    perform realtime.send(
      jsonb_build_object('record', to_jsonb(new)),
      'notification_insert',
      'prosme:user:' || new.related_user_id::text,
      true
    );
  end if;
  return null;
end;
$$;

revoke all on function app_private.broadcast_prosme_notification()
  from public, anon, authenticated;

drop trigger if exists admin_notifications_broadcast
  on public.admin_notifications;
create trigger admin_notifications_broadcast
after insert on public.admin_notifications
for each row execute function app_private.broadcast_prosme_notification();

create or replace function app_private.broadcast_prosme_thread()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.threads%rowtype;
  event_name text;
begin
  if tg_op = 'DELETE' then
    row_data := old;
  else
    row_data := new;
  end if;
  event_name := 'thread_' || lower(tg_op);

  perform realtime.send(
    jsonb_build_object('record', to_jsonb(row_data)),
    event_name,
    'prosme:user:' || row_data.user_id::text,
    true
  );
  if row_data.artisan_id <> row_data.user_id then
    perform realtime.send(
      jsonb_build_object('record', to_jsonb(row_data)),
      event_name,
      'prosme:user:' || row_data.artisan_id::text,
      true
    );
  end if;
  return null;
end;
$$;

revoke all on function app_private.broadcast_prosme_thread()
  from public, anon, authenticated;

drop trigger if exists threads_broadcast on public.threads;
create trigger threads_broadcast
after insert or update or delete on public.threads
for each row execute function app_private.broadcast_prosme_thread();

create or replace function app_private.broadcast_prosme_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.messages%rowtype;
begin
  if tg_op = 'DELETE' then
    row_data := old;
  else
    row_data := new;
  end if;

  perform realtime.send(
    jsonb_build_object('record', to_jsonb(row_data)),
    'message_' || lower(tg_op),
    'prosme:thread:' || row_data.thread_id::text,
    true
  );
  return null;
end;
$$;

revoke all on function app_private.broadcast_prosme_message()
  from public, anon, authenticated;

drop trigger if exists messages_broadcast on public.messages;
create trigger messages_broadcast
after insert or update or delete on public.messages
for each row execute function app_private.broadcast_prosme_message();
