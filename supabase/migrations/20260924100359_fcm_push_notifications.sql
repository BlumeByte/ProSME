-- ============================================================
-- Device tokens (one row per installed app instance)
-- ============================================================
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null unique,
  platform text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_own" on public.device_tokens
  for select using ((select auth.uid()) = user_id);
create policy "device_tokens_insert_own" on public.device_tokens
  for insert with check ((select auth.uid()) = user_id);
create policy "device_tokens_update_own" on public.device_tokens
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "device_tokens_delete_own" on public.device_tokens
  for delete using ((select auth.uid()) = user_id);

-- ============================================================
-- Push outbox (mirrors email_outbox; drained by send-push-outbox)
-- ============================================================
create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  related_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  data jsonb,
  sent_at timestamptz,
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

alter table public.push_outbox enable row level security;

create policy "Authenticated users can create push tasks" on public.push_outbox
  for insert with check (true);
create policy "Admins can read push outbox" on public.push_outbox
  for select using (app_private.is_admin());

-- ============================================================
-- Queue a push for the same priority notification types the app already
-- fires a foreground local notification for (bid, booking, job, account).
-- ============================================================
create or replace function public.queue_admin_notification_push()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare readable_body text; kind text := lower(coalesce(new.type, ''));
begin
  if new.related_user_id is null then
    return new;
  end if;
  if not (kind ~ 'bid' or kind ~ 'booking' or kind ~ '(job|work)' or kind ~ '(account|password|profile)') then
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

drop trigger if exists admin_notifications_queue_push on public.admin_notifications;
create trigger admin_notifications_queue_push after insert on public.admin_notifications
  for each row execute function public.queue_admin_notification_push();

-- ============================================================
-- Drain the push outbox every minute, same secret/pattern as email.
-- ============================================================
select cron.schedule('drain-push-outbox', '* * * * *', $$
  select net.http_post(
    url := 'https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/send-push-outbox',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-dispatch-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'email_dispatch_secret'
        limit 1
      )
    ),
    body := jsonb_build_object('limit', 25, 'maxAttempts', 5),
    timeout_milliseconds := 10000
  );
$$);
