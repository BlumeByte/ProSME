-- Security hardening, part 1: privilege escalation, notification abuse,
-- over-broad grants and policy bugs found in the 2026-10-04 audit.

-- ---------------------------------------------------------------------------
-- 1. profiles: users must not be able to change their own role, verification
--    state or other server-controlled columns. Previously the self-update and
--    self-insert policies had no column restrictions, so any signed-in user
--    could `update profiles set role = 'admin'` and gain every admin power
--    (app_private.is_admin() reads this column).
-- ---------------------------------------------------------------------------
create or replace function app_private.guard_profile_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  existing public.profiles%rowtype;
begin
  -- Service role / postgres / cron have no JWT subject: trusted server code.
  if caller is null then
    return new;
  end if;
  -- Admins may edit anything (the admin dashboard also goes through the
  -- service role, this keeps in-app admin screens working).
  if app_private.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- A user may only ever create their own, non-privileged profile.
    if new.id is distinct from caller then
      raise exception 'Cannot create a profile for another user.' using errcode = '42501';
    end if;

    -- `upsert` fires BEFORE INSERT even when the row already exists, and the
    -- ON CONFLICT DO UPDATE branch then copies the (trigger-modified) proposed
    -- row. Pin the server-controlled columns to what is stored so a login-time
    -- profile sync can neither escalate nor accidentally reset them.
    select * into existing from public.profiles where id = new.id;
    if found then
      new.role := existing.role;
      new.verification_status := existing.verification_status;
      new.verification_expires_at := existing.verification_expires_at;
      new.verification_reviewed_at := existing.verification_reviewed_at;
      new.verification_retry_after := existing.verification_retry_after;
      new.verification_notes := existing.verification_notes;
      new.email_verified := existing.email_verified;
      new.phone_verified := existing.phone_verified;
      new.rating_summary := existing.rating_summary;
      new.tenant_id := existing.tenant_id;
      return new;
    end if;

    if new.role is null or new.role not in ('customer', 'artisan') then
      new.role := 'customer';
    end if;
    new.verification_status := 'pending';
    new.verification_expires_at := null;
    new.verification_reviewed_at := null;
    new.verification_retry_after := null;
    new.verification_notes := null;
    -- Trust only the auth provider's own confirmation of this exact address
    -- (OAuth sign-ins arrive already confirmed); everything else starts false
    -- and is set later by the account-verification edge function.
    new.email_verified := coalesce((
      select u.email_confirmed_at is not null
             and lower(coalesce(u.email, '')) = lower(coalesce(new.email, ''))
      from auth.users u
      where u.id = caller
    ), false);
    new.phone_verified := false;
    new.rating_summary := 0;
    new.tenant_id := 'default';
    return new;
  end if;

  -- UPDATE by a non-admin (necessarily their own row, enforced by RLS).
  new.id := old.id;
  new.created_at := old.created_at;
  new.role := old.role;
  new.rating_summary := old.rating_summary;
  new.tenant_id := old.tenant_id;
  new.verification_expires_at := old.verification_expires_at;
  new.verification_reviewed_at := old.verification_reviewed_at;
  new.verification_retry_after := old.verification_retry_after;
  new.verification_notes := old.verification_notes;

  -- Users may submit/resubmit for review ('pending') but never grant
  -- themselves 'verified' or 'rejected'.
  if new.verification_status is distinct from old.verification_status
     and new.verification_status <> 'pending' then
    new.verification_status := old.verification_status;
  end if;

  -- Verified flags are set only by the verification edge functions. Changing
  -- the contact detail invalidates the previous verification.
  new.email_verified := old.email_verified;
  new.phone_verified := old.phone_verified;
  if lower(coalesce(new.email, '')) is distinct from lower(coalesce(old.email, '')) then
    new.email_verified := false;
  end if;
  if coalesce(new.phone, '') is distinct from coalesce(old.phone, '') then
    new.phone_verified := false;
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_profile_write() from public, anon, authenticated;

drop trigger if exists profiles_guard_write on public.profiles;
create trigger profiles_guard_write
  before insert or update on public.profiles
  for each row execute function app_private.guard_profile_write();

-- Remove the redundant duplicate policy (tautological WHERE ... = ANY('admin','admin')).
drop policy if exists "Admins can update profiles" on public.profiles;

-- ---------------------------------------------------------------------------
-- 2. is_admin / delete_current_user: pin search_path.
-- ---------------------------------------------------------------------------
create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Notification fan-out abuse.
--    admin_notifications inserts fan out to realtime, e-mail, SMS and push for
--    `related_user_id`. Any user could previously send arbitrary text to any
--    other user (phishing) and trigger SMS spend. Non-admins may now only
--    insert the specific user-originated report/ticket types, and the
--    fan-out skips admin-directed types whose related_user_id is a third party
--    (e.g. the person being reported).
-- ---------------------------------------------------------------------------
create or replace function app_private.is_admin_directed_notification(kind text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select kind in (
    'support_ticket', 'chat_block', 'chat_report',
    'job_completion_report', 'account_deletion'
  );
$$;

drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
create policy "Users can create limited notifications"
  on public.admin_notifications
  for insert
  to authenticated
  with check (
    app_private.is_admin()
    or (
      actor_id = (select auth.uid())
      and length(title) <= 200
      and length(body) <= 4000
      and (
        (type = 'verification_payment_required'
          and related_user_id = (select auth.uid()))
        or app_private.is_admin_directed_notification(type)
      )
    )
  );

create or replace function public.queue_job_created_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.admin_notifications
    (type, title, body, actor_id, related_user_id, related_table, related_id)
  values (
    'job_created', 'New job request', new.title,
    new.created_by, new.created_by, 'jobs', new.id
  );
  return new;
end;
$$;

create or replace function public.queue_admin_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  readable_body text;
begin
  if new.related_user_id is null then
    return new;
  end if;
  if app_private.is_admin_directed_notification(new.type)
     and new.actor_id is distinct from new.related_user_id then
    return new;
  end if;

  readable_body := public.prosme_email_body_text(
    coalesce(nullif(new.body, ''), nullif(new.title, ''), 'You have a new ProSME alert.')
  );

  perform public.queue_profile_notification(
    new.related_user_id,
    coalesce(nullif(new.title, ''), 'New ProSME alert'),
    readable_body,
    left(readable_body, 120)
  );
  return new;
end;
$$;

create or replace function public.queue_admin_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public
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
  if app_private.is_admin_directed_notification(new.type)
     and new.actor_id is distinct from new.related_user_id then
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

create or replace function app_private.broadcast_prosme_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.related_user_id is not null
     and not (app_private.is_admin_directed_notification(new.type)
              and new.actor_id is distinct from new.related_user_id) then
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

-- ---------------------------------------------------------------------------
-- 4. Outbox tables: only server code (SECURITY DEFINER triggers / service
--    role) may queue push and SMS. push_outbox accepted inserts from anyone
--    (`with check (true)`, role public) => spoofed pushes to any user.
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated users can create push tasks" on public.push_outbox;
drop policy if exists "Admins can read push outbox" on public.push_outbox;
create policy "Admins can read push outbox"
  on public.push_outbox for select to authenticated
  using (app_private.is_admin());

drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;

drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
create policy "Authenticated users can create email tasks"
  on public.email_outbox for insert to authenticated
  with check (
    app_private.is_admin()
    or (
      related_user_id = (select auth.uid())
      and (to_email is null or lower(to_email) = 'blumebyte@gmail.com')
      and length(subject) <= 200
      and length(body) <= 5000
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Tighten broad SELECT policies on legacy tables.
-- ---------------------------------------------------------------------------
drop policy if exists "view applications" on public.applications;
create policy "view applications" on public.applications
  for select to authenticated
  using (
    artisan_id = (select auth.uid())
    or app_private.is_job_owner(job_id, (select auth.uid()))
    or app_private.is_admin()
  );

drop policy if exists "read applications" on public.job_applications;
create policy "read applications" on public.job_applications
  for select to authenticated
  using (
    artisan_id = (select auth.uid())
    or app_private.is_job_owner(job_id, (select auth.uid()))
    or app_private.is_admin()
  );

-- ---------------------------------------------------------------------------
-- 6. job_ratings: the INSERT check compared columns to themselves
--    (b.job_id = b.job_id), so any rating passed as long as one accepted bid
--    existed anywhere. Bind it to the actual job/artisan and require the same
--    on UPDATE so a rating cannot be re-pointed at another artisan.
-- ---------------------------------------------------------------------------
drop policy if exists "Job owners can rate accepted artisans" on public.job_ratings;
create policy "Job owners can rate accepted artisans"
  on public.job_ratings for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.jobs j
      where j.id = job_ratings.job_id and j.created_by = (select auth.uid())
    )
    and exists (
      select 1 from public.job_bids b
      where b.job_id = job_ratings.job_id
        and b.artisan_id = job_ratings.artisan_id
        and b.status = 'accepted'
    )
  );

drop policy if exists "Job owners can update own ratings" on public.job_ratings;
create policy "Job owners can update own ratings"
  on public.job_ratings for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.job_bids b
      where b.job_id = job_ratings.job_id
        and b.artisan_id = job_ratings.artisan_id
        and b.status = 'accepted'
    )
  );

-- ---------------------------------------------------------------------------
-- 7. job_bids: the "job owner can accept" UPDATE policy had no column limits,
--    so an owner could rewrite the artisan, job or price of any bid on their
--    job. Freeze identity columns, and freeze the price once accepted.
-- ---------------------------------------------------------------------------
create or replace function app_private.guard_job_bid_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or app_private.is_admin() then
    return new;
  end if;
  new.job_id := old.job_id;
  new.artisan_id := old.artisan_id;
  new.created_by_user_id := old.created_by_user_id;
  new.created_at := old.created_at;
  if old.status = 'accepted' then
    new.amount := old.amount;
  end if;
  return new;
end;
$$;

revoke all on function app_private.guard_job_bid_write() from public, anon, authenticated;

drop trigger if exists job_bids_guard_write on public.job_bids;
create trigger job_bids_guard_write
  before update on public.job_bids
  for each row execute function app_private.guard_job_bid_write();

-- ---------------------------------------------------------------------------
-- 8. Remove a stale storage policy for a bucket that no longer exists.
-- ---------------------------------------------------------------------------
drop policy if exists "public read images" on storage.objects;
