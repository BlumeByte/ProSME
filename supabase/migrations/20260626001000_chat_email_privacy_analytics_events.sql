-- Keep chat emails private and add first-party website/app analytics events.

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'web' check (source in ('web', 'app')),
  event_name text not null default 'page_view',
  path text,
  referrer text,
  user_agent text,
  session_id text,
  user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.analytics_events enable row level security;

grant insert on public.analytics_events to anon, authenticated;
grant select on public.analytics_events to authenticated;

drop policy if exists "Anyone can create analytics events" on public.analytics_events;
create policy "Anyone can create analytics events"
on public.analytics_events for insert
to anon, authenticated
with check (
  event_name in ('page_view', 'app_open', 'screen_view')
  and coalesce(length(path), 0) <= 500
  and coalesce(length(referrer), 0) <= 500
  and coalesce(length(user_agent), 0) <= 500
);

drop policy if exists "Admins can read analytics events" on public.analytics_events;
create policy "Admins can read analytics events"
on public.analytics_events for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  )
);

create index if not exists analytics_events_created_at_idx
on public.analytics_events (created_at desc);

create index if not exists analytics_events_event_name_idx
on public.analytics_events (event_name, created_at desc);

create or replace function public.queue_message_created_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
begin
  select case
    when t.user_id = new.sender_id then t.artisan_id
    else t.user_id
  end
  into recipient_id
  from public.threads t
  where t.id = new.thread_id;

  if recipient_id is not null and recipient_id <> new.sender_id then
    perform public.queue_profile_notification(
      recipient_id,
      'New ProSME chat message',
      'You have a new chat message in ProSME. Open the app to read and reply.',
      'New ProSME chat message. Open the app to reply.'
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_message_created_notifications()
from public, anon, authenticated;

drop trigger if exists messages_queue_notifications on public.messages;
create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_created_notifications();

update public.email_outbox
set subject = 'New ProSME chat message',
    body = 'You have a new chat message in ProSME. Open the app to read and reply.'
where sent_at is null
  and subject in ('New ProSME message', 'New ProSME chat message');
