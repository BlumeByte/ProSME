-- ============================================================
-- Respect each member's phone-notification preferences (profiles.
-- phone_notifications / blocked_phone_notification_types, already synced
-- from the app's Settings screen) before queuing a push.
-- ============================================================
create or replace function public.queue_admin_notification_push()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  readable_body text;
  kind text := lower(coalesce(new.type, ''));
  category text;
  recipient record;
begin
  if new.related_user_id is null then
    return new;
  end if;
  if not (kind ~ 'bid' or kind ~ 'booking' or kind ~ '(job|work)' or kind ~ '(account|password|profile)') then
    return new;
  end if;

  category := case
    when kind ~ 'bid' then 'bid'
    when kind ~ 'booking' then 'booking'
    when kind ~ '(job|work)' then 'job'
    else 'account'
  end;

  select phone_notifications, blocked_phone_notification_types
    into recipient
    from public.profiles where id = new.related_user_id;

  if recipient.phone_notifications is not null and not recipient.phone_notifications then
    return new;
  end if;
  if recipient.blocked_phone_notification_types is not null and (
    'all' = any(recipient.blocked_phone_notification_types)
    or category = any(recipient.blocked_phone_notification_types)
  ) then
    return new;
  end if;

  readable_body := coalesce(nullif(new.body, ''), nullif(new.title, ''), 'You have a new ProSME alert.');

  insert into public.push_outbox (related_user_id, title, body, data)
  values (
    new.related_user_id,
    coalesce(nullif(new.title, ''), 'New ProSME alert'),
    left(readable_body, 200),
    jsonb_build_object('type', new.type, 'related_table', new.related_table, 'related_id', new.related_id)
  );

  return new;
end;
$$;

-- ============================================================
-- New public job posted -> alert artisans whose profile categories
-- match the job's title/description (in-app notification; the existing
-- admin_notifications triggers already fan this out to email and push).
-- Direct/targeted requests (request_type <> 'public') are skipped here —
-- those already notify their target_artisan_id through the booking flow.
-- ============================================================
create or replace function public.queue_job_posted_alerts()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare artisan record; matched int := 0;
begin
  if coalesce(new.request_type, 'public') <> 'public' then
    return new;
  end if;

  for artisan in
    select p.id
    from public.profiles p
    where p.role = 'artisan'
      and p.id <> new.created_by
      and p.categories is not null
      and cardinality(p.categories) > 0
      and exists (
        select 1 from unnest(p.categories) c
        where new.title ilike '%' || c || '%' or coalesce(new.description, '') ilike '%' || c || '%'
      )
    limit 50
  loop
    insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
    values (
      'job_created',
      'New job near you: ' || new.title,
      coalesce(nullif(new.description, ''), 'A new job matching your services was just posted.'),
      new.created_by,
      artisan.id,
      'jobs',
      new.id
    );
    matched := matched + 1;
  end loop;

  return new;
end;
$$;

drop trigger if exists jobs_queue_posted_alerts on public.jobs;
create trigger jobs_queue_posted_alerts after insert on public.jobs
  for each row execute function public.queue_job_posted_alerts();
