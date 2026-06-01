alter table public.profiles
add column if not exists verification_status text not null default 'verified'
  check (verification_status in ('pending', 'verified', 'rejected')),
add column if not exists national_id_url text,
add column if not exists verification_notes text,
add column if not exists verification_submitted_at timestamptz,
add column if not exists verification_reviewed_at timestamptz,
add column if not exists location text,
add column if not exists categories text[] not null default '{}',
add column if not exists bio text,
add column if not exists momo_number text,
add column if not exists rating_summary numeric(3, 2) not null default 0;

update public.profiles
set verification_status = 'verified'
where role <> 'artisan' and verification_status = 'pending';

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  title text not null,
  body text not null default '',
  actor_id uuid references public.profiles(id) on delete set null,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.email_outbox (
  id uuid primary key default gen_random_uuid(),
  to_email text,
  subject text not null,
  body text not null default '',
  related_user_id uuid references public.profiles(id) on delete set null,
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.admin_notifications enable row level security;
alter table public.email_outbox enable row level security;

drop policy if exists "Admins can read notifications" on public.admin_notifications;
create policy "Admins can read notifications"
on public.admin_notifications for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

drop policy if exists "Authenticated users can create notifications" on public.admin_notifications;
create policy "Authenticated users can create notifications"
on public.admin_notifications for insert
to authenticated
with check (actor_id = auth.uid());

drop policy if exists "Users can create email tasks" on public.email_outbox;
create policy "Users can create email tasks"
on public.email_outbox for insert
to authenticated
with check (related_user_id = auth.uid() or exists (
  select 1 from public.profiles p
  where p.id = auth.uid() and p.role = 'admin'
));

drop policy if exists "Admins can read email tasks" on public.email_outbox;
create policy "Admins can read email tasks"
on public.email_outbox for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

drop policy if exists "Artisans can manage listings" on public.listings;
drop policy if exists "Verified artisans can manage listings" on public.listings;
create policy "Verified artisans can manage listings"
on public.listings for all
to authenticated
using (auth.uid() = artisan_id)
with check (
  auth.uid() = artisan_id
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'artisan'
      and p.verification_status = 'verified'
  )
);

drop policy if exists "Users can create jobs" on public.jobs;
drop policy if exists "Verified artisans can create jobs" on public.jobs;
create policy "Verified artisans can create jobs"
on public.jobs for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (
        p.role = 'customer'
        or (p.role = 'artisan' and p.verification_status = 'verified')
      )
  )
);
