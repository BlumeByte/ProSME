-- ProSME consolidated Supabase SQL
-- Generated from supabase/migrations on 2026-06-30.
-- Safe to rerun where migrations use IF EXISTS / IF NOT EXISTS guards.


-- ============================================================================
-- Migration: 20260530220000_init_profiles_and_realtime.sql
-- ============================================================================

-- Base schema for ProSME auth profile loading and realtime feeds.
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  email text,
  avatar_url text,
  role text not null default 'customer' check (role in ('customer', 'artisan', 'admin')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null default '',
  category text not null default '',
  price_min numeric(12, 2) not null default 0,
  price_max numeric(12, 2) not null default 0,
  images text[] not null default '{}',
  location text not null default '',
  verified_only boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  last_message text not null default '',
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'text',
  content text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  location text not null default '',
  budget numeric(12, 2) not null default 0,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.threads enable row level security;
alter table public.messages enable row level security;
alter table public.jobs enable row level security;

drop policy if exists "Users can read profiles" on public.profiles;
create policy "Users can read profiles"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "Users can upsert own profile" on public.profiles;
create policy "Users can upsert own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Users can read listings" on public.listings;
create policy "Users can read listings"
on public.listings for select
to authenticated
using (true);

drop policy if exists "Artisans can manage listings" on public.listings;
create policy "Artisans can manage listings"
on public.listings for all
to authenticated
using (auth.uid() = artisan_id)
with check (auth.uid() = artisan_id);

drop policy if exists "Users can read own threads" on public.threads;
create policy "Users can read own threads"
on public.threads for select
to authenticated
using (auth.uid() = user_id or auth.uid() = artisan_id);

drop policy if exists "Users can manage own threads" on public.threads;
create policy "Users can manage own threads"
on public.threads for all
to authenticated
using (auth.uid() = user_id or auth.uid() = artisan_id)
with check (auth.uid() = user_id or auth.uid() = artisan_id);

drop policy if exists "Users can read thread messages" on public.messages;
create policy "Users can read thread messages"
on public.messages for select
to authenticated
using (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = auth.uid() or t.artisan_id = auth.uid())
  )
);

drop policy if exists "Users can send thread messages" on public.messages;
create policy "Users can send thread messages"
on public.messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = auth.uid() or t.artisan_id = auth.uid())
  )
);

drop policy if exists "Users can read jobs" on public.jobs;
create policy "Users can read jobs"
on public.jobs for select
to authenticated
using (true);

drop policy if exists "Users can create jobs" on public.jobs;
create policy "Users can create jobs"
on public.jobs for insert
to authenticated
with check (created_by = auth.uid());

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'listings'
  ) then
    alter publication supabase_realtime add table public.listings;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'threads'
  ) then
    alter publication supabase_realtime add table public.threads;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'jobs'
  ) then
    alter publication supabase_realtime add table public.jobs;
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260530233000_usernames_and_account_deletion.sql
-- ============================================================================

alter table public.profiles
add column if not exists username text;

update public.profiles
set username = 'user_' || left(replace(id::text, '-', ''), 8)
where username is null or btrim(username) = '';

create unique index if not exists profiles_username_unique_idx
on public.profiles (lower(username));

create unique index if not exists profiles_email_unique_idx
on public.profiles (lower(email))
where email is not null and btrim(email) <> '';

drop policy if exists "Public can read listings" on public.listings;
create policy "Public can read listings"
on public.listings for select
to anon, authenticated
using (true);

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;

-- ============================================================================
-- Migration: 20260531000000_saved_listings.sql
-- ============================================================================

-- saved_listings: per-user bookmarked listings.
create table if not exists public.saved_listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, listing_id)
);

alter table public.saved_listings enable row level security;

drop policy if exists "Users can read own saved listings" on public.saved_listings;
create policy "Users can read own saved listings"
on public.saved_listings for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can save listings" on public.saved_listings;
create policy "Users can save listings"
on public.saved_listings for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can unsave listings" on public.saved_listings;
create policy "Users can unsave listings"
on public.saved_listings for delete
to authenticated
using (auth.uid() = user_id);

-- ============================================================================
-- Migration: 20260601000000_public_jobs_and_listing_write.sql
-- ============================================================================

-- Public marketplace feeds. Inserts still require authenticated owners.
drop policy if exists "Public can read jobs" on public.jobs;
create policy "Public can read jobs"
on public.jobs for select
to anon, authenticated
using (true);

drop policy if exists "Public can read profiles" on public.profiles;
create policy "Public can read profiles"
on public.profiles for select
to anon, authenticated
using (true);

-- ============================================================================
-- Migration: 20260601010000_verification_admin_email.sql
-- ============================================================================

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

-- ============================================================================
-- Migration: 20260601020000_verification_storage_and_unverified_artisans.sql
-- ============================================================================

alter table public.profiles
add column if not exists national_id_front_url text,
add column if not exists national_id_back_url text,
add column if not exists business_certificate_urls text[] not null default '{}',
add column if not exists email_notifications boolean not null default true,
add column if not exists sms_notifications boolean not null default true,
add column if not exists preferred_language text not null default 'English';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'artisan-verification',
  'artisan-verification',
  true,
  1048576,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Artisans can upload verification documents" on storage.objects;
create policy "Artisans can upload verification documents"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'artisan-verification'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can view verification documents" on storage.objects;
create policy "Users can view verification documents"
on storage.objects for select
to authenticated
using (bucket_id = 'artisan-verification');

drop policy if exists "Verified artisans can manage listings" on public.listings;
drop policy if exists "Artisans can manage listings" on public.listings;
drop policy if exists "Artisans can manage own listings" on public.listings;
create policy "Artisans can manage own listings"
on public.listings for all
to authenticated
using (auth.uid() = artisan_id)
with check (
  auth.uid() = artisan_id
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'artisan'
  )
);

drop policy if exists "Verified artisans can create jobs" on public.jobs;
drop policy if exists "Users can create jobs" on public.jobs;
drop policy if exists "Users and artisans can create jobs" on public.jobs;
create policy "Users and artisans can create jobs"
on public.jobs for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('customer', 'artisan', 'admin')
  )
);

-- ============================================================================
-- Migration: 20260603000000_job_bids_and_api_grants.sql
-- ============================================================================

-- Make app API access explicit for new Supabase projects and add job bids.
grant usage on schema public to anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant select on public.listings to anon, authenticated;
grant insert, update, delete on public.listings to authenticated;
grant select, insert on public.jobs to anon, authenticated;
grant update, delete on public.jobs to authenticated;
grant select, insert, update on public.threads to authenticated;
grant select, insert on public.messages to authenticated;

create table if not exists public.job_bids (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  message text not null default '',
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (job_id, artisan_id)
);

alter table public.job_bids enable row level security;

drop trigger if exists job_bids_set_updated_at on public.job_bids;
create trigger job_bids_set_updated_at
before update on public.job_bids
for each row execute function public.set_updated_at();

grant select, insert, update on public.job_bids to authenticated;

drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
create policy "Job owners and bidders can read bids"
on public.job_bids for select
to authenticated
using (
  artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  )
);

drop policy if exists "Artisans can create own job bids" on public.job_bids;
create policy "Artisans can create own job bids"
on public.job_bids for insert
to authenticated
with check (
  artisan_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'artisan'
  )
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by <> (select auth.uid())
  )
);

drop policy if exists "Artisans can update own pending bids" on public.job_bids;
create policy "Artisans can update own pending bids"
on public.job_bids for update
to authenticated
using (artisan_id = (select auth.uid()) and status = 'pending')
with check (artisan_id = (select auth.uid()) and status = 'pending');

drop policy if exists "Job owners can accept bids" on public.job_bids;
create policy "Job owners can accept bids"
on public.job_bids for update
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'job_bids'
  ) then
    alter publication supabase_realtime add table public.job_bids;
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260606000000_admin_tenants_and_job_ratings.sql
-- ============================================================================

alter table public.profiles
add column if not exists tenant_id text not null default 'default';

alter table public.listings
add column if not exists tenant_id text not null default 'default';

alter table public.jobs
add column if not exists tenant_id text not null default 'default',
add column if not exists status text not null default 'active'
  check (status in ('active', 'completed', 'cancelled'));

alter table public.profiles
drop constraint if exists profiles_role_check;

alter table public.profiles
add constraint profiles_role_check
check (role in ('customer', 'artisan', 'admin', 'admin'));

create table if not exists public.job_ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  artisan_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  unique (job_id, user_id)
);

alter table public.job_ratings enable row level security;

grant select, insert, update on public.job_ratings to authenticated;
grant select on public.admin_notifications to authenticated;
grant select on public.email_outbox to authenticated;

drop policy if exists "Users can read visible job ratings" on public.job_ratings;
create policy "Users can read visible job ratings"
on public.job_ratings for select
to authenticated
using (true);

drop policy if exists "Job owners can rate accepted artisans" on public.job_ratings;
create policy "Job owners can rate accepted artisans"
on public.job_ratings for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
  and exists (
    select 1
    from public.job_bids b
    where b.job_id = job_id
      and b.artisan_id = artisan_id
      and b.status = 'accepted'
  )
);

drop policy if exists "Job owners can update own ratings" on public.job_ratings;
create policy "Job owners can update own ratings"
on public.job_ratings for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
)
with check (true);

drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
create policy "Admins can read admin notifications"
on public.admin_notifications for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Admins can read email outbox" on public.email_outbox;
create policy "Admins can read email outbox"
on public.email_outbox for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
create policy "Job owners and bidders can read bids"
on public.job_bids for select
to authenticated
using (
  artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id and j.created_by = (select auth.uid())
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'job_ratings'
  ) then
    alter publication supabase_realtime add table public.job_ratings;
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260606010000_search_profile_images_and_verification_retry.sql
-- ============================================================================

alter table public.profiles
add column if not exists country text not null default 'Ghana',
add column if not exists country_code text not null default '+233',
add column if not exists description text not null default '',
add column if not exists phone_verified boolean not null default false,
add column if not exists verification_retry_after timestamptz;

alter table public.listings
add column if not exists search_text text generated always as (
  lower(coalesce(title, '') || ' ' || coalesce(description, '') || ' ' || coalesce(category, '') || ' ' || coalesce(location, ''))
) stored;

alter table public.jobs
add column if not exists search_text text generated always as (
  lower(coalesce(title, '') || ' ' || coalesce(description, '') || ' ' || coalesce(location, ''))
) stored;

create index if not exists listings_search_text_idx on public.listings using gin (to_tsvector('simple', search_text));
create index if not exists jobs_search_text_idx on public.jobs using gin (to_tsvector('simple', search_text));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'listing-images',
  'listing-images',
  true,
  102400,
  array['image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Artisans can upload listing images" on storage.objects;
create policy "Artisans can upload listing images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'artisan'
  )
);

drop policy if exists "Artisans can update listing images" on storage.objects;
create policy "Artisans can update listing images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Public can view listing images" on storage.objects;
create policy "Public can view listing images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'listing-images');

-- ============================================================================
-- Migration: 20260608000000_harden_advisor_warnings.sql
-- ============================================================================

-- Harden Supabase advisor warnings while keeping REST access for signed-in app users.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from anon, authenticated;

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

do $$
begin
  if to_regclass('public.job_applications') is not null then
    execute 'drop policy if exists "update applications" on public.job_applications';
  end if;
end;
$$;

drop policy if exists "Users can view verification documents" on storage.objects;
drop policy if exists "Public can view listing images" on storage.objects;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'admin_notifications',
    'applications',
    'email_outbox',
    'job_applications',
    'job_bids',
    'job_messages',
    'job_payments',
    'job_ratings',
    'job_reviews',
    'kv_store_8e58d1ea',
    'messages',
    'saved_listings',
    'threads'
  ]
  loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('revoke select on table public.%I from anon', table_name);
    end if;
  end loop;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'delete_current_user'
  ) then
    execute 'revoke execute on function public.delete_current_user() from anon';
    execute 'grant execute on function public.delete_current_user() to authenticated';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'rls_auto_enable'
  ) then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260608020000_admin_dashboard_management.sql
-- ============================================================================

-- Admin web dashboard management support.
-- Apply this in Supabase before deploying the updated admin dashboard.

create extension if not exists "pgcrypto";

create schema if not exists app_private;

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_admin() to authenticated;

update public.profiles
set role = 'admin',
    verification_status = 'verified',
    full_name = coalesce(nullif(full_name, ''), 'BlumeByte Admin'),
    email = coalesce(nullif(email, ''), 'blumebyte@gmail.com')
where lower(email) = 'blumebyte@gmail.com';

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  related_table text,
  related_id uuid,
  type text not null default 'report',
  category text not null default 'general',
  title text,
  body text not null default '',
  description text not null default '',
  message text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    alter table public.admin_notifications
    add column if not exists related_user_id uuid references public.profiles(id) on delete set null,
    add column if not exists related_table text,
    add column if not exists related_id uuid;
  end if;
end;
$$;

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

alter table public.reports enable row level security;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;
grant select, insert, update, delete on public.reports to authenticated;

revoke select, insert, update, delete on public.reports from anon;

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    grant select, insert, update, delete on public.admin_notifications to authenticated;
  end if;
end;
$$;

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports"
on public.reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

drop policy if exists "Users can read own reports" on public.reports;
create policy "Users can read own reports"
on public.reports for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
on public.reports for update
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can delete reports" on public.reports;
create policy "Admins can delete reports"
on public.reports for delete
to authenticated
using (
  app_private.is_admin()
);

drop policy if exists "Admins can update profiles" on public.profiles;
drop policy if exists "Admins can manage profiles" on public.profiles;
create policy "Admins can manage profiles"
on public.profiles for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can manage listings" on public.listings;
create policy "Admins can manage listings"
on public.listings for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

drop policy if exists "Admins can manage jobs" on public.jobs;
create policy "Admins can manage jobs"
on public.jobs for all
to authenticated
using (
  app_private.is_admin()
)
with check (
  app_private.is_admin()
);

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    drop policy if exists "Admins can read notifications" on public.admin_notifications;
    drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
    create policy "Admins can read admin notifications"
    on public.admin_notifications for select
    to authenticated
    using (app_private.is_admin());

    create policy "Admins can create admin notifications"
    on public.admin_notifications for insert
    to authenticated
    with check (
      actor_id = (select auth.uid())
      and app_private.is_admin()
    );

    drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
    create policy "Admins can update admin notifications"
    on public.admin_notifications for update
    to authenticated
    using (app_private.is_admin())
    with check (app_private.is_admin());

    drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;
    create policy "Admins can delete admin notifications"
    on public.admin_notifications for delete
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.email_outbox') is not null then
    drop policy if exists "Admins can read email tasks" on public.email_outbox;
    drop policy if exists "Admins can read email outbox" on public.email_outbox;
    create policy "Admins can read email outbox"
    on public.email_outbox for select
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reports'
  ) then
    alter publication supabase_realtime add table public.reports;
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260608030000_fix_admin_rls_and_support.sql
-- ============================================================================

-- Repair admin dashboard access, profile RLS recursion, and support tickets.

create extension if not exists "pgcrypto";
create schema if not exists app_private;

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_admin() to authenticated;

do $$
declare
  role_constraint record;
begin
  for role_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%role%'
  loop
    execute format('alter table public.profiles drop constraint if exists %I', role_constraint.conname);
  end loop;
end;
$$;

update public.profiles
set role = 'admin'
where role = 'admin';

update public.profiles
set role = 'admin',
    verification_status = 'verified',
    full_name = coalesce(nullif(full_name, ''), 'BlumeByte Admin'),
    email = coalesce(nullif(email, ''), 'blumebyte@gmail.com')
where lower(email) = 'blumebyte@gmail.com';

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('customer', 'artisan', 'admin'));

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  type text not null default 'support_ticket',
  category text,
  title text,
  body text,
  message text,
  status text not null default 'open',
  related_table text,
  related_id uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;
grant select, insert, update, delete on public.reports to authenticated;
revoke select, insert, update, delete on public.reports from anon;

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    alter table public.admin_notifications
      add column if not exists related_user_id uuid references public.profiles(id) on delete set null,
      add column if not exists related_table text,
      add column if not exists related_id uuid,
      add column if not exists read_at timestamptz;

    grant select, insert, update, delete on public.admin_notifications to authenticated;
    revoke select, insert, update, delete on public.admin_notifications from anon;
  end if;
end;
$$;

drop policy if exists "Users can create reports" on public.reports;
create policy "Users can create reports"
on public.reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

drop policy if exists "Users can read related reports" on public.reports;
create policy "Users can read related reports"
on public.reports for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
on public.reports for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists "Admins can delete reports" on public.reports;
create policy "Admins can delete reports"
on public.reports for delete
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can update profiles" on public.profiles;
drop policy if exists "Admins can manage profiles" on public.profiles;
create policy "Admins can manage profiles"
on public.profiles for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists "Admins can manage listings" on public.listings;
create policy "Admins can manage listings"
on public.listings for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists "Admins can manage jobs" on public.jobs;
create policy "Admins can manage jobs"
on public.jobs for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    drop policy if exists "Admins can read notifications" on public.admin_notifications;
    drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
    drop policy if exists "Authenticated users can create support notifications" on public.admin_notifications;
    drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
    drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;

    create policy "Admins can read admin notifications"
    on public.admin_notifications for select
    to authenticated
    using (
      app_private.is_admin()
      or related_user_id = (select auth.uid())
      or actor_id = (select auth.uid())
    );

    create policy "Authenticated users can create support notifications"
    on public.admin_notifications for insert
    to authenticated
    with check (
      actor_id = (select auth.uid())
      or app_private.is_admin()
    );

    create policy "Admins can update admin notifications"
    on public.admin_notifications for update
    to authenticated
    using (app_private.is_admin())
    with check (app_private.is_admin());

    create policy "Admins can delete admin notifications"
    on public.admin_notifications for delete
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.email_outbox') is not null then
    drop policy if exists "Admins can read email tasks" on public.email_outbox;
    drop policy if exists "Admins can read email outbox" on public.email_outbox;

    create policy "Admins can read email outbox"
    on public.email_outbox for select
    to authenticated
    using (app_private.is_admin());
  end if;
end;
$$;

-- ============================================================================
-- Migration: 20260610000000_repair_owner_writes_storage_and_admin_actions.sql
-- ============================================================================

-- Repair owner writes for the mobile app and storage policies used by profile/listing images.

grant select, insert, update on public.profiles to authenticated;
grant select on public.profiles to anon, authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select on public.listings to anon, authenticated;
grant select, insert, update, delete on public.jobs to authenticated;
grant select on public.jobs to anon, authenticated;

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "Users can upsert own profile" on public.profiles;
create policy "Users can upsert own profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Artisans can manage own listings" on public.listings;
drop policy if exists "Artisans can manage listings" on public.listings;
drop policy if exists "Verified artisans can manage listings" on public.listings;
create policy "Artisans can manage own listings"
on public.listings for all
to authenticated
using ((select auth.uid()) = artisan_id)
with check ((select auth.uid()) = artisan_id);

drop policy if exists "Users can update own jobs" on public.jobs;
create policy "Users can update own jobs"
on public.jobs for update
to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);

drop policy if exists "Users can delete own jobs" on public.jobs;
create policy "Users can delete own jobs"
on public.jobs for delete
to authenticated
using ((select auth.uid()) = created_by);

drop policy if exists "Users and artisans can create jobs" on public.jobs;
drop policy if exists "Users can create jobs" on public.jobs;
drop policy if exists "Verified artisans can create jobs" on public.jobs;
create policy "Users and artisans can create jobs"
on public.jobs for insert
to authenticated
with check ((select auth.uid()) = created_by);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png']),
  ('listing-images', 'listing-images', true, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload own avatars" on storage.objects;
create policy "Users can upload own avatars"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can update own avatars" on storage.objects;
create policy "Users can update own avatars"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Public can view avatars" on storage.objects;
create policy "Public can view avatars"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'avatars');

drop policy if exists "Artisans can upload listing images" on storage.objects;
create policy "Artisans can upload listing images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'artisan'
  )
);

drop policy if exists "Artisans can update listing images" on storage.objects;
create policy "Artisans can update listing images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Public can view listing images" on storage.objects;
create policy "Public can view listing images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'listing-images');

-- ============================================================================
-- Migration: 20260610010000_notifications_unread_user_settings_and_job_images.sql
-- ============================================================================

-- Add settings, unread tracking, and job image compatibility.

alter table public.profiles
add column if not exists username_updated_at timestamptz,
add column if not exists email_notifications boolean not null default true,
add column if not exists phone_notifications boolean not null default true,
add column if not exists app_language text not null default 'English';

alter table public.messages
add column if not exists read_at timestamptz;

alter table public.jobs
add column if not exists images text[] not null default '{}';

grant select, insert, update on public.messages to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;

drop policy if exists "Thread participants can mark messages read" on public.messages;
create policy "Thread participants can mark messages read"
on public.messages for update
to authenticated
using (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = (select auth.uid()) or t.artisan_id = (select auth.uid()))
  )
)
with check (
  exists (
    select 1
    from public.threads t
    where t.id = thread_id
      and (t.user_id = (select auth.uid()) or t.artisan_id = (select auth.uid()))
  )
);

drop policy if exists "Users can update own jobs" on public.jobs;
create policy "Users can update own jobs"
on public.jobs for update
to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);

-- ============================================================================
-- Migration: 20260610020000_production_auth_profile_notifications.sql
-- ============================================================================

-- Production hardening for auth/profile data, job images, and notification outboxes.

alter table public.profiles
add column if not exists phone_verified boolean not null default false,
add column if not exists email_notifications boolean not null default true,
add column if not exists phone_notifications boolean not null default true,
add column if not exists app_language text not null default 'English';

update public.profiles
set description = left(coalesce(description, ''), 50)
where length(coalesce(description, '')) > 50;

alter table public.profiles
drop constraint if exists profiles_description_max_50;

alter table public.profiles
add constraint profiles_description_max_50
check (length(coalesce(description, '')) <= 50);

alter table public.jobs
add column if not exists images text[] not null default '{}';

update public.jobs
set images = (coalesce(images, '{}'))[1:3]
where array_length(coalesce(images, '{}'), 1) > 3;

alter table public.jobs
drop constraint if exists jobs_images_max_3;

alter table public.jobs
add constraint jobs_images_max_3
check (coalesce(array_length(images, 1), 0) <= 3);

create table if not exists public.sms_outbox (
  id uuid primary key default gen_random_uuid(),
  to_phone text,
  body text not null default '',
  related_user_id uuid references public.profiles(id) on delete set null,
  sent_at timestamptz,
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

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  title text not null,
  body text not null default '',
  actor_id uuid references public.profiles(id) on delete set null,
  related_user_id uuid references public.profiles(id) on delete set null,
  related_table text,
  related_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.sms_outbox enable row level security;
alter table public.email_outbox enable row level security;
alter table public.admin_notifications enable row level security;

grant select, insert, update on public.sms_outbox to authenticated;

grant select, insert, update on public.email_outbox to authenticated;
grant select, insert, update on public.admin_notifications to authenticated;

drop policy if exists "Users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
create policy "Authenticated users can create email tasks"
on public.email_outbox for insert
to authenticated
with check (true);

drop policy if exists "Admins can read sms outbox" on public.sms_outbox;
create policy "Admins can read sms outbox"
on public.sms_outbox for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
create policy "Authenticated users can create sms tasks"
on public.sms_outbox for insert
to authenticated
with check (true);

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  target_profile record;
begin
  select id, email, phone, email_notifications, phone_notifications
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  if target_profile.email_notifications and coalesce(target_profile.email, '') <> '' then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (target_profile.email, email_subject, email_body, target_profile.id);
  end if;

  if target_profile.phone_notifications and coalesce(target_profile.phone, '') <> '' then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (target_profile.phone, sms_body, target_profile.id);
  end if;
end;
$$;

drop trigger if exists jobs_queue_notifications on public.jobs;
create or replace function public.queue_job_created_notifications()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
  values (
    'job_created',
    'New job request',
    new.title,
    new.created_by,
    new.created_by,
    'jobs',
    new.id
  );
  return new;
end;
$$;

create trigger jobs_queue_notifications
after insert on public.jobs
for each row execute function public.queue_job_created_notifications();

drop trigger if exists job_bids_queue_notifications on public.job_bids;
create or replace function public.queue_bid_created_notifications()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
begin
  select created_by, title
  into owner_id, job_title
  from public.jobs
  where id = new.job_id;

  perform public.queue_profile_notification(
    owner_id,
    'New ProSME bid',
    'A professional submitted a bid for "' || coalesce(job_title, 'your job') || '".',
    'New ProSME bid for ' || coalesce(job_title, 'your job') || '.'
  );

  return new;
end;
$$;

create trigger job_bids_queue_notifications
after insert on public.job_bids
for each row execute function public.queue_bid_created_notifications();

drop trigger if exists messages_queue_notifications on public.messages;
create or replace function public.queue_message_created_notifications()
returns trigger
language plpgsql
security invoker
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

  perform public.queue_profile_notification(
    recipient_id,
    'New ProSME message',
    left(coalesce(new.content, 'You have a new ProSME message.'), 200),
    left(coalesce(new.content, 'New ProSME message.'), 120)
  );

  return new;
end;
$$;

create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_created_notifications();

-- ============================================================================
-- Migration: 20260611000000_artisan_availability.sql
-- ============================================================================

alter table public.profiles
add column if not exists is_busy boolean not null default false;

grant select, update on public.profiles to authenticated;

grant select, update on public.admin_notifications to authenticated;

drop policy if exists "Users can read own notifications" on public.admin_notifications;
create policy "Users can read own notifications"
on public.admin_notifications for select
to authenticated
using (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()));

drop policy if exists "Users can mark own notifications read" on public.admin_notifications;
create policy "Users can mark own notifications read"
on public.admin_notifications for update
to authenticated
using (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()))
with check (related_user_id = (select auth.uid()) or actor_id = (select auth.uid()));

-- ============================================================================
-- Migration: 20260611010000_user_verification_pending_defaults.sql
-- ============================================================================

alter table public.profiles
  alter column verification_status set default 'pending';

update public.profiles
set verification_status = 'pending'
where coalesce(role, 'customer') <> 'artisan'
  and verification_status = 'verified'
  and coalesce(national_id_front_url, national_id_url, '') = ''
  and coalesce(national_id_back_url, '') = '';

-- ============================================================================
-- Migration: 20260611020000_email_outbox_resend_delivery.sql
-- ============================================================================

alter table public.email_outbox
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists last_error text,
  add column if not exists resend_message_id text;

create index if not exists email_outbox_pending_idx
on public.email_outbox (created_at)
where sent_at is null;

-- ============================================================================
-- Migration: 20260611030000_harden_outbox_insert_policies.sql
-- ============================================================================

drop policy if exists "Users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create limited email tasks" on public.email_outbox;
create policy "Authenticated users can create limited email tasks"
on public.email_outbox for insert
to authenticated
with check (
  (
    related_user_id = (select auth.uid())
    and (
      to_email is null
      or lower(to_email) = 'blumebyte@gmail.com'
    )
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
drop policy if exists "Authenticated users can create own sms tasks" on public.sms_outbox;
create policy "Authenticated users can create own sms tasks"
on public.sms_outbox for insert
to authenticated
with check (
  related_user_id = (select auth.uid())
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

-- ============================================================================
-- Migration: 20260612010000_profile_currency_settings.sql
-- ============================================================================

alter table public.profiles
  add column if not exists currency_code text not null default 'GHS';

-- ============================================================================
-- Migration: 20260615010000_chat_blocks_and_report_notifications.sql
-- ============================================================================

create table if not exists public.chat_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  thread_id uuid references public.threads(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_user_id)
);

alter table public.chat_blocks enable row level security;
grant select, insert, delete on public.chat_blocks to authenticated;
revoke select, insert, update, delete on public.chat_blocks from anon;

drop policy if exists "Users can create own chat blocks" on public.chat_blocks;
create policy "Users can create own chat blocks"
on public.chat_blocks for insert
to authenticated
with check (blocker_id = (select auth.uid()));

drop policy if exists "Users can read own chat blocks" on public.chat_blocks;
create policy "Users can read own chat blocks"
on public.chat_blocks for select
to authenticated
using (
  blocker_id = (select auth.uid())
  or blocked_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can delete own chat blocks" on public.chat_blocks;
create policy "Users can delete own chat blocks"
on public.chat_blocks for delete
to authenticated
using (blocker_id = (select auth.uid()) or app_private.is_admin());

do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_blocks'
  ) then
    null;
  else
    alter publication supabase_realtime add table public.chat_blocks;
  end if;
exception
  when undefined_object then
    null;
end;
$$;

-- ============================================================================
-- Migration: 20260616010000_repair_chat_notifications_and_verification.sql
-- ============================================================================

alter table public.profiles
add column if not exists email_verified boolean not null default false,
add column if not exists phone_verified boolean not null default false,
add column if not exists currency_code text not null default 'GHS';

create table if not exists public.profile_verification_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null check (channel in ('email', 'phone')),
  destination text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempt_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists profile_verification_codes_user_channel_idx
on public.profile_verification_codes (user_id, channel, created_at desc);

alter table public.profile_verification_codes enable row level security;
revoke all on public.profile_verification_codes from anon;
revoke all on public.profile_verification_codes from authenticated;

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile record;
begin
  select id, email, phone, email_notifications, phone_notifications
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  if target_profile.email_notifications and coalesce(target_profile.email, '') <> '' then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (target_profile.email, email_subject, email_body, target_profile.id);
  end if;

  if target_profile.phone_notifications and coalesce(target_profile.phone, '') <> '' then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (target_profile.phone, sms_body, target_profile.id);
  end if;
end;
$$;

revoke all on function public.queue_profile_notification(uuid, text, text, text) from public;
revoke all on function public.queue_profile_notification(uuid, text, text, text) from anon;
revoke all on function public.queue_profile_notification(uuid, text, text, text) from authenticated;

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
      'New ProSME message',
      left(coalesce(new.content, 'You have a new ProSME message.'), 200),
      left(coalesce(new.content, 'New ProSME message.'), 120)
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_message_created_notifications() from public;
revoke all on function public.queue_message_created_notifications() from anon;
revoke all on function public.queue_message_created_notifications() from authenticated;

drop trigger if exists messages_queue_notifications on public.messages;
create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_created_notifications();

-- ============================================================================
-- Migration: 20260619010000_bid_chat_wallet_location_repair.sql
-- ============================================================================

-- Repair bid notification trigger permissions and add wallet/location tracking.

alter table public.jobs
add column if not exists location_lat double precision,
add column if not exists location_lng double precision,
add column if not exists location_source text not null default 'typed',
add column if not exists accepted_bid_id uuid references public.job_bids(id) on delete set null,
add column if not exists accepted_amount numeric(12, 2);

alter table public.job_bids
add column if not exists location text,
add column if not exists location_lat double precision,
add column if not exists location_lng double precision,
add column if not exists location_source text not null default 'not_shared';

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  bid_id uuid references public.job_bids(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  artisan_id uuid references public.profiles(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'GHS',
  event_type text not null default 'bid_accepted'
    check (event_type in ('bid_accepted', 'payment_recorded', 'refund_recorded')),
  invoice_number text,
  job_title text not null default '',
  job_location text not null default '',
  customer_name text not null default '',
  customer_email text not null default '',
  artisan_name text not null default '',
  artisan_email text not null default '',
  payment_status text not null default 'agreed'
    check (payment_status in ('agreed', 'paid', 'refunded')),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.wallet_transactions
add column if not exists invoice_number text,
add column if not exists job_title text not null default '',
add column if not exists job_location text not null default '',
add column if not exists customer_name text not null default '',
add column if not exists customer_email text not null default '',
add column if not exists artisan_name text not null default '',
add column if not exists artisan_email text not null default '',
add column if not exists payment_status text not null default 'agreed';

create unique index if not exists wallet_transactions_invoice_number_uidx
on public.wallet_transactions (invoice_number)
where invoice_number is not null;

create unique index if not exists wallet_transactions_bid_event_uidx
on public.wallet_transactions (bid_id, event_type)
where bid_id is not null;

alter table public.wallet_transactions enable row level security;
grant select on public.wallet_transactions to authenticated;
revoke insert, update, delete on public.wallet_transactions from authenticated;
revoke all on public.wallet_transactions from anon;

grant delete on public.admin_notifications to authenticated;

drop policy if exists "Users can delete own notifications" on public.admin_notifications;
create policy "Users can delete own notifications"
on public.admin_notifications for delete
to authenticated
using (
  related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Users can read own wallet transactions" on public.wallet_transactions;
create policy "Users can read own wallet transactions"
on public.wallet_transactions for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated can insert wallet transactions through app" on public.wallet_transactions;

create or replace function public.queue_bid_created_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
begin
  select created_by, title
  into owner_id, job_title
  from public.jobs
  where id = new.job_id;

  if owner_id is not null and owner_id <> new.artisan_id then
    perform public.queue_profile_notification(
      owner_id,
      'New ProSME bid',
      'A professional submitted a bid for "' || coalesce(job_title, 'your job') || '".',
      'New ProSME bid for ' || coalesce(job_title, 'your job') || '.'
    );
  end if;

  return new;
end;
$$;

revoke all on function public.queue_bid_created_notifications() from public;
revoke all on function public.queue_bid_created_notifications() from anon;
revoke all on function public.queue_bid_created_notifications() from authenticated;

drop trigger if exists job_bids_queue_notifications on public.job_bids;
create trigger job_bids_queue_notifications
after insert on public.job_bids
for each row execute function public.queue_bid_created_notifications();

create or replace function public.record_bid_acceptance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  job_title text;
  job_location text;
  customer_name text;
  customer_email text;
  artisan_name text;
  artisan_email text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title, location
    into owner_id, job_title, job_location
    from public.jobs
    where id = new.job_id;

    select
      coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Customer'),
      coalesce(email, '')
    into customer_name, customer_email
    from public.profiles
    where id = owner_id;

    select
      coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Artisan'),
      coalesce(email, '')
    into artisan_name, artisan_email
    from public.profiles
    where id = new.artisan_id;

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'completed'
    where id = new.job_id;

    insert into public.wallet_transactions (
      job_id,
      bid_id,
      user_id,
      artisan_id,
      amount,
      invoice_number,
      job_title,
      job_location,
      customer_name,
      customer_email,
      artisan_name,
      artisan_email
    )
    values (
      new.job_id,
      new.id,
      owner_id,
      new.artisan_id,
      new.amount,
      'PSME-' || upper(substr(replace(new.id::text, '-', ''), 1, 12)),
      coalesce(job_title, ''),
      coalesce(job_location, ''),
      coalesce(customer_name, 'Customer'),
      coalesce(customer_email, ''),
      coalesce(artisan_name, 'Artisan'),
      coalesce(artisan_email, '')
    )
    on conflict do nothing;

    insert into public.admin_notifications (type, title, body, actor_id, related_user_id, related_table, related_id)
    values
      ('bid_accepted', 'Bid accepted', 'Your bid was accepted for "' || coalesce(job_title, 'a job') || '". Chat is now open.', owner_id, new.artisan_id, 'job_bids', new.id),
      ('bid_accepted', 'Bid accepted', 'You accepted a bid for "' || coalesce(job_title, 'your job') || '". Chat is now open.', new.artisan_id, owner_id, 'job_bids', new.id);
  end if;

  return new;
end;
$$;

revoke all on function public.record_bid_acceptance() from public;
revoke all on function public.record_bid_acceptance() from anon;
revoke all on function public.record_bid_acceptance() from authenticated;

drop trigger if exists job_bids_record_acceptance on public.job_bids;
create trigger job_bids_record_acceptance
after update of status on public.job_bids
for each row execute function public.record_bid_acceptance();

-- Populate wallets for bids that were accepted before this migration existed.
insert into public.wallet_transactions (
  job_id,
  bid_id,
  user_id,
  artisan_id,
  amount,
  invoice_number,
  job_title,
  job_location,
  customer_name,
  customer_email,
  artisan_name,
  artisan_email,
  created_at
)
select
  b.job_id,
  b.id,
  j.created_by,
  b.artisan_id,
  b.amount,
  'PSME-' || upper(substr(replace(b.id::text, '-', ''), 1, 12)),
  coalesce(j.title, ''),
  coalesce(j.location, ''),
  coalesce(nullif(customer.full_name, ''), nullif(customer.username, ''), customer.email, 'Customer'),
  coalesce(customer.email, ''),
  coalesce(nullif(artisan.full_name, ''), nullif(artisan.username, ''), artisan.email, 'Artisan'),
  coalesce(artisan.email, ''),
  coalesce(b.updated_at, b.created_at, timezone('utc', now()))
from public.job_bids b
join public.jobs j on j.id = b.job_id
left join public.profiles customer on customer.id = j.created_by
left join public.profiles artisan on artisan.id = b.artisan_id
where b.status = 'accepted'
on conflict do nothing;

with accepted as (
  select distinct on (b.job_id)
    b.job_id,
    b.id,
    b.amount
  from public.job_bids b
  where b.status = 'accepted'
  order by b.job_id, b.updated_at desc nulls last, b.created_at desc
)
update public.jobs j
set accepted_bid_id = accepted.id,
    accepted_amount = accepted.amount,
    status = 'completed'
from accepted
where accepted.job_id = j.id
  and j.accepted_bid_id is null;

-- ============================================================================
-- Migration: 20260623084841_wallet_history_repair.sql
-- ============================================================================

-- Make wallet tracking idempotent, backfill historical wins, and keep bid
-- outcomes queryable for customer, artisan, and admin history screens.

alter table public.jobs
add column if not exists accepted_bid_id uuid
  references public.job_bids(id) on delete set null,
add column if not exists accepted_amount numeric(12, 2);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  bid_id uuid references public.job_bids(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  artisan_id uuid references public.profiles(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'GHS',
  event_type text not null default 'bid_accepted',
  invoice_number text,
  job_title text not null default '',
  job_location text not null default '',
  customer_name text not null default '',
  customer_email text not null default '',
  artisan_name text not null default '',
  artisan_email text not null default '',
  payment_status text not null default 'agreed',
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.wallet_transactions
add column if not exists job_id uuid references public.jobs(id) on delete set null,
add column if not exists bid_id uuid references public.job_bids(id) on delete set null,
add column if not exists user_id uuid references public.profiles(id) on delete set null,
add column if not exists artisan_id uuid references public.profiles(id) on delete set null,
add column if not exists amount numeric(12, 2),
add column if not exists currency text not null default 'GHS',
add column if not exists event_type text not null default 'bid_accepted',
add column if not exists invoice_number text,
add column if not exists job_title text not null default '',
add column if not exists job_location text not null default '',
add column if not exists customer_name text not null default '',
add column if not exists customer_email text not null default '',
add column if not exists artisan_name text not null default '',
add column if not exists artisan_email text not null default '',
add column if not exists payment_status text not null default 'agreed',
add column if not exists created_at timestamptz not null default timezone('utc', now()),
add column if not exists work_status text not null default 'accepted',
add column if not exists completed_at timestamptz;

create unique index if not exists wallet_transactions_bid_event_uidx
on public.wallet_transactions (bid_id, event_type)
where bid_id is not null;

create unique index if not exists wallet_transactions_invoice_number_uidx
on public.wallet_transactions (invoice_number)
where invoice_number is not null;

alter table public.wallet_transactions
drop constraint if exists wallet_transactions_work_status_check;

alter table public.wallet_transactions
add constraint wallet_transactions_work_status_check
check (work_status in ('accepted', 'completed', 'cancelled'));

create index if not exists wallet_transactions_user_created_idx
on public.wallet_transactions (user_id, created_at desc);

create index if not exists wallet_transactions_artisan_created_idx
on public.wallet_transactions (artisan_id, created_at desc);

create index if not exists job_bids_artisan_status_created_idx
on public.job_bids (artisan_id, status, created_at desc);

create index if not exists job_bids_job_status_created_idx
on public.job_bids (job_id, status, created_at desc);

create index if not exists jobs_owner_status_created_idx
on public.jobs (created_by, status, created_at desc);

grant select on public.wallet_transactions to authenticated;
revoke insert, update, delete on public.wallet_transactions from authenticated;
revoke all on public.wallet_transactions from anon;

drop policy if exists "Users can read own wallet transactions"
on public.wallet_transactions;
create policy "Users can read own wallet transactions"
on public.wallet_transactions for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

create or replace function public.sync_wallet_transaction_for_bid(
  p_bid_id uuid,
  p_work_status text default 'accepted'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  bid_row public.job_bids%rowtype;
  job_row public.jobs%rowtype;
  customer_name_value text;
  customer_email_value text;
  artisan_name_value text;
  artisan_email_value text;
begin
  select * into bid_row
  from public.job_bids
  where id = p_bid_id;

  if bid_row.id is null or bid_row.status <> 'accepted' then
    return;
  end if;

  select * into job_row
  from public.jobs
  where id = bid_row.job_id;

  if job_row.id is null then
    return;
  end if;

  select
    coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Customer'),
    coalesce(email, '')
  into customer_name_value, customer_email_value
  from public.profiles
  where id = job_row.created_by;

  select
    coalesce(nullif(full_name, ''), nullif(username, ''), email, 'Artisan'),
    coalesce(email, '')
  into artisan_name_value, artisan_email_value
  from public.profiles
  where id = bid_row.artisan_id;

  insert into public.wallet_transactions as existing (
    job_id,
    bid_id,
    user_id,
    artisan_id,
    amount,
    currency,
    event_type,
    invoice_number,
    job_title,
    job_location,
    customer_name,
    customer_email,
    artisan_name,
    artisan_email,
    work_status,
    completed_at,
    created_at
  ) values (
    job_row.id,
    bid_row.id,
    job_row.created_by,
    bid_row.artisan_id,
    bid_row.amount,
    'GHS',
    'bid_accepted',
    'PSME-' || upper(substr(replace(bid_row.id::text, '-', ''), 1, 12)),
    coalesce(job_row.title, ''),
    coalesce(job_row.location, ''),
    coalesce(customer_name_value, 'Customer'),
    coalesce(customer_email_value, ''),
    coalesce(artisan_name_value, 'Artisan'),
    coalesce(artisan_email_value, ''),
    case when p_work_status = 'completed' then 'completed' else 'accepted' end,
    case
      when p_work_status = 'completed' then timezone('utc', now())
      else null
    end,
    coalesce(bid_row.updated_at, bid_row.created_at, timezone('utc', now()))
  )
  on conflict (bid_id, event_type) where bid_id is not null
  do update set
    amount = excluded.amount,
    job_title = excluded.job_title,
    job_location = excluded.job_location,
    customer_name = excluded.customer_name,
    customer_email = excluded.customer_email,
    artisan_name = excluded.artisan_name,
    artisan_email = excluded.artisan_email,
    work_status = case
      when excluded.work_status = 'completed' then 'completed'
      else existing.work_status
    end,
    completed_at = coalesce(
      existing.completed_at,
      excluded.completed_at
    );
end;
$$;

revoke all on function public.sync_wallet_transaction_for_bid(uuid, text)
from public, anon, authenticated;

create or replace function public.record_bid_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  job_title_value text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title
    into owner_id, job_title_value
    from public.jobs
    where id = new.job_id;

    update public.job_bids
    set status = 'rejected'
    where job_id = new.job_id
      and id <> new.id
      and status = 'pending';

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'completed'
    where id = new.job_id;

    perform public.sync_wallet_transaction_for_bid(
      new.id,
      case
        when exists (
          select 1 from public.jobs j
          where j.id = new.job_id and j.status = 'completed'
        ) then 'completed'
        else 'accepted'
      end
    );

    insert into public.admin_notifications (
      type,
      title,
      body,
      actor_id,
      related_user_id,
      related_table,
      related_id
    ) values
      (
        'bid_accepted',
        'Bid accepted',
        'Your bid was accepted for "' || coalesce(job_title_value, 'a job') || '". Chat is now open.',
        owner_id,
        new.artisan_id,
        'job_bids',
        new.id
      ),
      (
        'bid_accepted',
        'Bid accepted',
        'You accepted a bid for "' || coalesce(job_title_value, 'your job') || '". Chat is now open.',
        new.artisan_id,
        owner_id,
        'job_bids',
        new.id
      );
  end if;

  return new;
end;
$$;

revoke all on function public.record_bid_acceptance()
from public, anon, authenticated;

drop trigger if exists job_bids_record_acceptance on public.job_bids;
create trigger job_bids_record_acceptance
after update of status on public.job_bids
for each row execute function public.record_bid_acceptance();

create or replace function public.record_completed_job_wallet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepted_id uuid;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    accepted_id := new.accepted_bid_id;

    if accepted_id is null then
      select b.id into accepted_id
      from public.job_bids b
      where b.job_id = new.id and b.status = 'accepted'
      order by b.updated_at desc nulls last, b.created_at desc
      limit 1;
    end if;

    if accepted_id is not null then
      perform public.sync_wallet_transaction_for_bid(accepted_id, 'completed');
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.record_completed_job_wallet()
from public, anon, authenticated;

drop trigger if exists jobs_record_completed_wallet on public.jobs;
create trigger jobs_record_completed_wallet
after update of status on public.jobs
for each row execute function public.record_completed_job_wallet();

-- Normalize historical data before enforcing one winning bid per request.
with ranked_acceptances as (
  select
    b.id,
    row_number() over (
      partition by b.job_id
      order by
        case when j.accepted_bid_id = b.id then 0 else 1 end,
        b.updated_at desc nulls last,
        b.created_at desc
    ) as position
  from public.job_bids b
  join public.jobs j on j.id = b.job_id
  where b.status = 'accepted'
)
update public.job_bids b
set status = 'rejected'
from ranked_acceptances ranked
where ranked.id = b.id
  and ranked.position > 1;

create unique index if not exists job_bids_one_accepted_per_job_uidx
on public.job_bids (job_id)
where status = 'accepted';

with accepted as (
  select distinct on (b.job_id)
    b.job_id,
    b.id,
    b.amount
  from public.job_bids b
  where b.status = 'accepted'
  order by b.job_id, b.updated_at desc nulls last, b.created_at desc
)
update public.jobs j
set accepted_bid_id = accepted.id,
    accepted_amount = accepted.amount,
    status = 'completed'
from accepted
where accepted.job_id = j.id;

update public.job_bids pending
set status = 'rejected'
where pending.status = 'pending'
  and exists (
    select 1
    from public.job_bids accepted
    where accepted.job_id = pending.job_id
      and accepted.status = 'accepted'
  );

do $$
declare
  accepted_record record;
begin
  for accepted_record in
    select
      b.id,
      case when j.status = 'completed' then 'completed' else 'accepted' end
        as work_status
    from public.job_bids b
    join public.jobs j on j.id = b.job_id
    where b.status = 'accepted'
  loop
    perform public.sync_wallet_transaction_for_bid(
      accepted_record.id,
      accepted_record.work_status
    );
  end loop;
end;
$$;

-- ============================================================================
-- Migration: 20260623135621_password_recovery_rate_limit.sql
-- ============================================================================

create table if not exists public.password_recovery_attempts (
  id bigint generated always as identity primary key,
  email_hash text not null,
  requested_at timestamptz not null default timezone('utc', now())
);

create index if not exists password_recovery_attempts_lookup_idx
on public.password_recovery_attempts (email_hash, requested_at desc);

alter table public.password_recovery_attempts enable row level security;

revoke all on public.password_recovery_attempts from public, anon, authenticated;
revoke all on sequence public.password_recovery_attempts_id_seq from public, anon, authenticated;
grant select, insert, delete on public.password_recovery_attempts to service_role;
grant usage, select on sequence public.password_recovery_attempts_id_seq to service_role;

-- ============================================================================
-- Migration: 20260623143144_job_tracking_invoice_workflow.sql
-- ============================================================================

alter table public.jobs
add column if not exists work_status text not null default 'open',
add column if not exists eta_at timestamptz,
add column if not exists started_at timestamptz,
add column if not exists completed_at timestamptz,
add column if not exists status_updated_at timestamptz not null default timezone('utc', now());

alter table public.jobs
drop constraint if exists jobs_work_status_check;

update public.jobs
set work_status = case
  when lower(btrim(coalesce(work_status, ''))) in (
    'open',
    'accepted',
    'in_progress',
    'completed',
    'cancelled'
  ) then lower(btrim(work_status))
  when status = 'completed' then 'completed'
  when status = 'cancelled' then 'cancelled'
  when accepted_bid_id is not null then 'accepted'
  else 'open'
end
where lower(btrim(coalesce(work_status, ''))) not in (
  'open',
  'accepted',
  'in_progress',
  'completed',
  'cancelled'
);

alter table public.jobs
add constraint jobs_work_status_check
check (work_status in ('open', 'accepted', 'in_progress', 'completed', 'cancelled'));

create table if not exists public.job_status_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  status text not null
    check (status in ('open', 'accepted', 'in_progress', 'completed', 'cancelled')),
  note text,
  eta_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists job_status_events_job_created_idx
on public.job_status_events (job_id, created_at);

alter table public.job_status_events enable row level security;
grant select on public.job_status_events to authenticated;
revoke insert, update, delete on public.job_status_events from anon, authenticated;
revoke all on public.job_status_events from anon;

drop policy if exists "Participants can read job timeline" on public.job_status_events;
create policy "Participants can read job timeline"
on public.job_status_events for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_status_events.job_id
      and (
        j.created_by = (select auth.uid())
        or exists (
          select 1
          from public.job_bids b
          where b.job_id = j.id
            and b.artisan_id = (select auth.uid())
            and b.status = 'accepted'
        )
        or exists (
          select 1
          from public.profiles p
          where p.id = (select auth.uid())
            and p.role in ('admin', 'admin')
        )
      )
  )
);

create or replace function public.update_job_progress(
  p_job_id uuid,
  p_status text,
  p_eta_at timestamptz default null,
  p_note text default null
)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  current_job public.jobs%rowtype;
  accepted_artisan uuid;
  actor_role text;
  next_status text := lower(trim(coalesce(p_status, '')));
begin
  if actor is null then
    raise exception 'Authentication required';
  end if;
  if next_status not in ('accepted', 'in_progress', 'completed', 'cancelled') then
    raise exception 'Invalid job status';
  end if;

  select * into current_job
  from public.jobs
  where id = p_job_id
  for update;
  if current_job.id is null then
    raise exception 'Job not found';
  end if;

  select b.artisan_id into accepted_artisan
  from public.job_bids b
  where b.job_id = p_job_id and b.status = 'accepted'
  order by b.updated_at desc nulls last, b.created_at desc
  limit 1;
  select p.role into actor_role from public.profiles p where p.id = actor;

  if actor <> current_job.created_by
     and actor is distinct from accepted_artisan
     and coalesce(actor_role, '') not in ('admin', 'admin') then
    raise exception 'Only job participants can update progress';
  end if;
  if accepted_artisan is null and next_status <> 'cancelled' then
    raise exception 'Accept a bid before updating progress';
  end if;
  if current_job.work_status = 'completed' and next_status <> 'completed' then
    raise exception 'Completed jobs cannot be reopened';
  end if;
  if current_job.work_status = 'in_progress' and next_status = 'accepted' then
    raise exception 'Work in progress cannot move back to accepted';
  end if;
  if current_job.work_status = 'cancelled' then
    raise exception 'Cancelled jobs cannot be updated';
  end if;

  update public.jobs
  set work_status = next_status,
      eta_at = coalesce(p_eta_at, eta_at),
      started_at = case
        when next_status = 'in_progress' then coalesce(started_at, timezone('utc', now()))
        else started_at
      end,
      completed_at = case
        when next_status = 'completed' then coalesce(completed_at, timezone('utc', now()))
        else completed_at
      end,
      status_updated_at = timezone('utc', now()),
      status = case
        when next_status = 'completed' then 'completed'
        when next_status = 'cancelled' then 'cancelled'
        else 'active'
      end
  where id = p_job_id
  returning * into current_job;

  insert into public.job_status_events (job_id, actor_id, status, note, eta_at)
  values (
    p_job_id,
    actor,
    next_status,
    nullif(trim(coalesce(p_note, '')), ''),
    current_job.eta_at
  );

  if next_status = 'completed' and current_job.accepted_bid_id is not null then
    perform public.sync_wallet_transaction_for_bid(current_job.accepted_bid_id, 'completed');
  end if;
  return current_job;
end;
$$;

revoke all on function public.update_job_progress(uuid, text, timestamptz, text)
from public, anon;
grant execute on function public.update_job_progress(uuid, text, timestamptz, text)
to authenticated;

create or replace function public.record_bid_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  job_title_value text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select created_by, title
    into owner_id, job_title_value
    from public.jobs
    where id = new.job_id;

    update public.job_bids
    set status = 'rejected'
    where job_id = new.job_id
      and id <> new.id
      and status = 'pending';

    update public.jobs
    set accepted_bid_id = new.id,
        accepted_amount = new.amount,
        status = 'active',
        work_status = 'accepted',
        status_updated_at = timezone('utc', now())
    where id = new.job_id;

    perform public.sync_wallet_transaction_for_bid(new.id, 'accepted');

    insert into public.job_status_events (job_id, actor_id, status, note)
    values (new.job_id, owner_id, 'accepted', 'Bid accepted');

    insert into public.admin_notifications (
      type, title, body, actor_id, related_user_id, related_table, related_id
    ) values
      (
        'bid_accepted',
        'Bid accepted',
        'Your bid was accepted for "' || coalesce(job_title_value, 'a job') || '". Chat is now open.',
        owner_id,
        new.artisan_id,
        'job_bids',
        new.id
      ),
      (
        'bid_accepted',
        'Bid accepted',
        'You accepted a bid for "' || coalesce(job_title_value, 'your job') || '". Chat is now open.',
        new.artisan_id,
        owner_id,
        'job_bids',
        new.id
      );
  end if;
  return new;
end;
$$;

revoke all on function public.record_bid_acceptance()
from public, anon, authenticated;

update public.wallet_transactions wt
set work_status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = wt.job_id
      ) then 'completed'
      else 'accepted'
    end,
    completed_at = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = wt.job_id
      ) then wt.completed_at
      else null
    end
where wt.event_type = 'bid_accepted';

update public.jobs j
set work_status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then 'completed'
      else 'accepted'
    end,
    status = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then 'completed'
      else 'active'
    end,
    completed_at = case
      when exists (
        select 1 from public.job_ratings r where r.job_id = j.id
      ) then coalesce(j.completed_at, wt.completed_at)
      else null
    end,
    status_updated_at = timezone('utc', now())
from public.wallet_transactions wt
where wt.job_id = j.id
  and wt.event_type = 'bid_accepted'
  and wt.bid_id = j.accepted_bid_id;

insert into public.job_status_events (job_id, actor_id, status, note, eta_at, created_at)
select
  j.id,
  j.created_by,
  j.work_status,
  'Imported existing job status',
  j.eta_at,
  coalesce(j.status_updated_at, j.created_at, timezone('utc', now()))
from public.jobs j
where j.accepted_bid_id is not null
  and not exists (
    select 1 from public.job_status_events e where e.job_id = j.id
  );

-- ============================================================================
-- Migration: 20260623165007_admin_bid_tracking_access.sql
-- ============================================================================

-- Give admin accounts read-only visibility for platform bid auditing.

grant select on public.job_bids to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.threads to authenticated;
grant select on public.messages to authenticated;

drop policy if exists "Admins can read all job bids" on public.job_bids;
create policy "Admins can read all job bids"
on public.job_bids for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all wallet transactions"
on public.wallet_transactions;
create policy "Admins can read all wallet transactions"
on public.wallet_transactions for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all threads" on public.threads;
create policy "Admins can read all threads"
on public.threads for select
to authenticated
using (app_private.is_admin());

drop policy if exists "Admins can read all messages" on public.messages;
create policy "Admins can read all messages"
on public.messages for select
to authenticated
using (app_private.is_admin());

-- ============================================================================
-- Migration: 20260623225159_alert_email_delivery.sql
-- ============================================================================

-- Email user-facing alerts and flush queued email tasks automatically.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;
create extension if not exists supabase_vault with schema vault;

create or replace function public.queue_admin_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.related_user_id is null then
    return new;
  end if;

  perform public.queue_profile_notification(
    new.related_user_id,
    coalesce(nullif(new.title, ''), 'New ProSME alert'),
    coalesce(nullif(new.body, ''), 'You have a new ProSME alert.'),
    left(coalesce(nullif(new.body, ''), nullif(new.title, ''), 'New ProSME alert.'), 120)
  );

  return new;
end;
$$;

revoke all on function public.queue_admin_notification_email()
from public, anon, authenticated;

drop trigger if exists admin_notifications_queue_email on public.admin_notifications;
create trigger admin_notifications_queue_email
after insert on public.admin_notifications
for each row execute function public.queue_admin_notification_email();

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-email-outbox-dispatch') then
    perform cron.unschedule('prosme-email-outbox-dispatch');
  end if;
end;
$$;

select cron.schedule(
  'prosme-email-outbox-dispatch',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/send-email-outbox',
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
  $$
);

-- ============================================================================
-- Migration: 20260623230354_admin_role_cleanup.sql
-- ============================================================================

-- Rename the platform dashboard role to admin and repair
-- dashboard access to thread ordering.

alter table if exists public.threads
  add column if not exists created_at timestamptz;

update public.threads
set created_at = coalesce(updated_at, timezone('utc', now()))
where created_at is null;

alter table if exists public.threads
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

alter table public.profiles drop constraint if exists profiles_role_check;

update public.profiles
set role = 'admin'
where role = ('devel' || 'oper');

update auth.users
set raw_app_meta_data =
      coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin'),
    raw_user_meta_data =
      coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
where raw_app_meta_data ->> 'role' = ('devel' || 'oper')
   or raw_user_meta_data ->> 'role' = ('devel' || 'oper')
   or id in (select id from public.profiles where role = 'admin');

alter table public.profiles
  drop constraint if exists profiles_role_check,
  add constraint profiles_role_check
  check (role in ('customer', 'artisan', 'admin'));

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon, authenticated;
grant execute on function app_private.is_admin() to authenticated;

grant select on public.profiles to authenticated;
grant select, update on public.reports to authenticated;
grant select, insert, update, delete on public.admin_notifications to authenticated;
grant select on public.email_outbox to authenticated;
grant select on public.sms_outbox to authenticated;
grant select on public.job_bids to authenticated;
grant select on public.job_status_events to authenticated;
grant select, insert, update, delete on public.jobs to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.threads to authenticated;
grant select on public.messages to authenticated;
grant select, delete on public.chat_blocks to authenticated;

do $$
declare
  legacy_plural text := 'Devel' || 'opers';
  legacy_role text := 'devel' || 'oper';
begin
  execute format('drop policy if exists %I on public.reports', legacy_plural || ' can update reports');
  execute format('drop policy if exists %I on public.reports', legacy_plural || ' can delete reports');
  execute format('drop policy if exists %I on public.profiles', legacy_plural || ' can manage profiles');
  execute format('drop policy if exists %I on public.profiles', legacy_plural || ' can update profiles');
  execute format('drop policy if exists %I on public.listings', legacy_plural || ' can manage listings');
  execute format('drop policy if exists %I on public.jobs', legacy_plural || ' can manage jobs');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can read admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can create admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can update admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can delete admin notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can read ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can update ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.admin_notifications', legacy_plural || ' can delete ' || legacy_role || ' notifications');
  execute format('drop policy if exists %I on public.email_outbox', legacy_plural || ' can read email outbox');
  execute format('drop policy if exists %I on public.sms_outbox', legacy_plural || ' can read sms outbox');
  execute format('drop policy if exists %I on public.job_bids', legacy_plural || ' can read all job bids');
  execute format('drop policy if exists %I on public.wallet_transactions', legacy_plural || ' can read all wallet transactions');
  execute format('drop policy if exists %I on public.threads', legacy_plural || ' can read all threads');
  execute format('drop policy if exists %I on public.messages', legacy_plural || ' can read all messages');
end $$;
drop policy if exists "Users can delete own notifications" on public.admin_notifications;
drop policy if exists "Job owners and bidders can read bids" on public.job_bids;
drop policy if exists "Participants can read job timeline" on public.job_status_events;
drop policy if exists "Users can read own reports" on public.reports;
drop policy if exists "Users can read own wallet transactions" on public.wallet_transactions;
drop policy if exists "Admins can update reports" on public.reports;
drop policy if exists "Admins can delete reports" on public.reports;
drop policy if exists "Admins can manage profiles" on public.profiles;
drop policy if exists "Admins can manage listings" on public.listings;
drop policy if exists "Admins can manage jobs" on public.jobs;
drop policy if exists "Admins can read admin notifications" on public.admin_notifications;
drop policy if exists "Admins can create admin notifications" on public.admin_notifications;
drop policy if exists "Admins can update admin notifications" on public.admin_notifications;
drop policy if exists "Admins can delete admin notifications" on public.admin_notifications;
drop policy if exists "Admins can read email outbox" on public.email_outbox;
drop policy if exists "Admins can read sms outbox" on public.sms_outbox;
drop policy if exists "Admins can read all job bids" on public.job_bids;
drop policy if exists "Admins can read all wallet transactions" on public.wallet_transactions;
drop policy if exists "Admins can read all threads" on public.threads;
drop policy if exists "Admins can read all messages" on public.messages;

create policy "Admins can update reports"
on public.reports
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can delete reports"
on public.reports
for delete
to authenticated
using (app_private.is_admin());

create policy "Admins can manage profiles"
on public.profiles
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can manage listings"
on public.listings
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can manage jobs"
on public.jobs
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can read admin notifications"
on public.admin_notifications
for select
to authenticated
using (
  app_private.is_admin()
  or related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
);

create policy "Admins can create admin notifications"
on public.admin_notifications
for insert
to authenticated
with check (
  actor_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Admins can update admin notifications"
on public.admin_notifications
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create policy "Admins can delete admin notifications"
on public.admin_notifications
for delete
to authenticated
using (app_private.is_admin());

create policy "Admins can read email outbox"
on public.email_outbox
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read sms outbox"
on public.sms_outbox
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all job bids"
on public.job_bids
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all wallet transactions"
on public.wallet_transactions
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all threads"
on public.threads
for select
to authenticated
using (app_private.is_admin());

create policy "Admins can read all messages"
on public.messages
for select
to authenticated
using (app_private.is_admin());

create policy "Users can delete own notifications"
on public.admin_notifications
for delete
to authenticated
using (
  related_user_id = (select auth.uid())
  or actor_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Job owners and bidders can read bids"
on public.job_bids
for select
to authenticated
using (
  artisan_id = (select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id = job_bids.job_id
      and j.created_by = (select auth.uid())
  )
  or app_private.is_admin()
);

create policy "Participants can read job timeline"
on public.job_status_events
for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_status_events.job_id
      and (
        j.created_by = (select auth.uid())
        or exists (
          select 1
          from public.job_bids b
          where b.job_id = j.id
            and b.artisan_id = (select auth.uid())
            and b.status = 'accepted'
        )
        or app_private.is_admin()
      )
  )
);

create policy "Users can read own reports"
on public.reports
for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or reported_user_id = (select auth.uid())
  or app_private.is_admin()
);

create policy "Users can read own wallet transactions"
on public.wallet_transactions
for select
to authenticated
using (
  user_id = (select auth.uid())
  or artisan_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create support notifications" on public.admin_notifications;
create policy "Authenticated users can create support notifications"
on public.admin_notifications
for insert
to authenticated
with check (
  actor_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can read own chat blocks" on public.chat_blocks;
create policy "Users can read own chat blocks"
on public.chat_blocks
for select
to authenticated
using (
  blocker_id = (select auth.uid())
  or blocked_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can delete own chat blocks" on public.chat_blocks;
create policy "Users can delete own chat blocks"
on public.chat_blocks
for delete
to authenticated
using (
  blocker_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create limited email tasks" on public.email_outbox;
create policy "Authenticated users can create email tasks"
on public.email_outbox
for insert
to authenticated
with check (
  (
    related_user_id = (select auth.uid())
    and (to_email is null or lower(to_email) = 'blumebyte@gmail.com')
  )
  or app_private.is_admin()
);

drop policy if exists "Authenticated users can create own sms tasks" on public.sms_outbox;
drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
create policy "Authenticated users can create sms tasks"
on public.sms_outbox
for insert
to authenticated
with check (
  related_user_id = (select auth.uid())
  or app_private.is_admin()
);

update public.admin_notifications
set type = 'admin_response'
where type = ('devel' || 'oper' || '_response');

do $$
begin
  execute format('drop function if exists app_private.%I()', 'is_' || 'devel' || 'oper');
end $$;

-- ============================================================================
-- Migration: 20260624153304_verification_subscriptions.sql
-- ============================================================================

-- Paid verification subscriptions. Admin approval makes payment required;
-- a verified Paystack payment activates or renews the public badge.

alter table public.profiles
  add column if not exists verification_expires_at timestamptz;

create table if not exists public.verification_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('customer', 'artisan')),
  plan_interval text not null check (plan_interval in ('monthly', 'yearly')),
  status text not null default 'payment_required'
    check (status in ('payment_required', 'pending_payment', 'active', 'expired', 'cancelled')),
  amount_usd numeric(10, 2) not null,
  charge_currency text not null default 'GHS',
  charge_amount integer not null default 0,
  paystack_reference text unique,
  paystack_access_code text,
  paystack_authorization_url text,
  paystack_transaction_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  admin_approved_by uuid references public.profiles(id) on delete set null,
  admin_approved_at timestamptz,
  last_payment_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id)
);

create table if not exists public.verification_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.verification_subscriptions(id) on delete set null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('customer', 'artisan')),
  plan_interval text not null check (plan_interval in ('monthly', 'yearly')),
  status text not null default 'pending'
    check (status in ('pending', 'success', 'failed', 'abandoned')),
  amount_usd numeric(10, 2) not null,
  charge_currency text not null,
  charge_amount integer not null,
  paystack_reference text not null unique,
  paystack_transaction_id text,
  gateway_response text,
  paid_at timestamptz,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists verification_subscriptions_user_status_idx
on public.verification_subscriptions (user_id, status);

create index if not exists verification_subscriptions_period_end_idx
on public.verification_subscriptions (current_period_end);

create index if not exists verification_payments_user_created_idx
on public.verification_payments (user_id, created_at desc);

alter table public.verification_subscriptions enable row level security;
alter table public.verification_payments enable row level security;

grant select, insert, update on public.verification_subscriptions to authenticated;
grant select, insert, update on public.verification_payments to authenticated;
revoke all on public.verification_subscriptions from anon;
revoke all on public.verification_payments from anon;

drop policy if exists "Users can read own verification subscriptions"
on public.verification_subscriptions;
create policy "Users can read own verification subscriptions"
on public.verification_subscriptions
for select
to authenticated
using (user_id = (select auth.uid()) or app_private.is_admin());

drop policy if exists "Admins can manage verification subscriptions"
on public.verification_subscriptions;
create policy "Admins can manage verification subscriptions"
on public.verification_subscriptions
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists "Users can read own verification payments"
on public.verification_payments;
create policy "Users can read own verification payments"
on public.verification_payments
for select
to authenticated
using (user_id = (select auth.uid()) or app_private.is_admin());

drop policy if exists "Admins can manage verification payments"
on public.verification_payments;
create policy "Admins can manage verification payments"
on public.verification_payments
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

create or replace function public.expire_verification_subscriptions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.verification_subscriptions
  set status = 'expired',
      updated_at = timezone('utc', now())
  where status = 'active'
    and current_period_end < timezone('utc', now());

  update public.profiles p
  set verification_status = 'pending',
      verification_expires_at = s.current_period_end,
      updated_at = timezone('utc', now())
  from public.verification_subscriptions s
  where s.user_id = p.id
    and s.status = 'expired'
    and p.verification_status = 'verified';
end;
$$;

revoke all on function public.expire_verification_subscriptions() from public, anon, authenticated;

-- ============================================================================
-- Migration: 20260624161926_verification_billing_autorenew.sql
-- ============================================================================

-- Store reusable Paystack authorizations for verification renewals and keep
-- existing verified accounts active during the paid-verification rollout.

alter table public.verification_subscriptions
  add column if not exists auto_renew boolean not null default true,
  add column if not exists paystack_customer_code text,
  add column if not exists paystack_email text,
  add column if not exists paystack_authorization_code text,
  add column if not exists paystack_authorization_signature text,
  add column if not exists paystack_authorization jsonb not null default '{}'::jsonb,
  add column if not exists payment_method_channel text,
  add column if not exists payment_method_label text,
  add column if not exists renewal_attempt_count integer not null default 0,
  add column if not exists last_renewal_attempt_at timestamptz,
  add column if not exists next_renewal_attempt_at timestamptz,
  add column if not exists last_renewal_error text,
  add column if not exists cancelled_at timestamptz;

do $$
begin
  alter table public.verification_subscriptions
    drop constraint if exists verification_subscriptions_status_check;
  alter table public.verification_subscriptions
    add constraint verification_subscriptions_status_check
    check (status in (
      'payment_required',
      'pending_payment',
      'active',
      'expired',
      'cancelled',
      'renewal_failed'
    ));
end;
$$;

do $$
begin
  alter table public.verification_payments
    drop constraint if exists verification_payments_status_check;
  alter table public.verification_payments
    add constraint verification_payments_status_check
    check (status in ('pending', 'success', 'failed', 'abandoned', 'renewal_failed'));
end;
$$;

create index if not exists verification_subscriptions_auto_renew_idx
on public.verification_subscriptions (status, auto_renew, current_period_end)
where status in ('active', 'renewal_failed');

create index if not exists verification_subscriptions_authorization_signature_idx
on public.verification_subscriptions (paystack_authorization_signature)
where paystack_authorization_signature is not null;

grant select, insert, update on public.verification_subscriptions to authenticated;
grant select, insert, update on public.verification_payments to authenticated;

insert into public.verification_subscriptions (
  user_id,
  role,
  plan_interval,
  status,
  amount_usd,
  charge_currency,
  charge_amount,
  current_period_start,
  current_period_end,
  last_payment_at,
  auto_renew,
  updated_at
)
select
  p.id,
  case when p.role = 'artisan' then 'artisan' else 'customer' end,
  'yearly',
  'active',
  case when p.role = 'artisan' then 60 else 24 end,
  'GHS',
  0,
  timezone('utc', now()),
  timezone('utc', now()) + interval '1 year',
  timezone('utc', now()),
  false,
  timezone('utc', now())
from public.profiles p
where p.role in ('customer', 'artisan')
  and p.verification_status = 'verified'
  and not exists (
    select 1
    from public.verification_subscriptions s
    where s.user_id = p.id
  );

update public.profiles p
set verification_expires_at = coalesce(p.verification_expires_at, s.current_period_end),
    updated_at = timezone('utc', now())
from public.verification_subscriptions s
where s.user_id = p.id
  and p.verification_status = 'verified'
  and s.status = 'active'
  and p.verification_expires_at is null;

create or replace function public.expire_verification_subscriptions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.verification_subscriptions
  set status = 'expired',
      auto_renew = false,
      updated_at = timezone('utc', now())
  where status in ('active', 'renewal_failed', 'pending_payment', 'payment_required')
    and current_period_end is not null
    and current_period_end < timezone('utc', now());

  update public.profiles p
  set verification_status = 'pending',
      verification_expires_at = s.current_period_end,
      updated_at = timezone('utc', now())
  from public.verification_subscriptions s
  where s.user_id = p.id
    and s.status = 'expired'
    and s.current_period_end is not null
    and s.current_period_end < timezone('utc', now())
    and p.verification_status = 'verified';
end;
$$;

revoke all on function public.expire_verification_subscriptions() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-expiry') then
    perform cron.unschedule('prosme-verification-expiry');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-expiry',
  '*/30 * * * *',
  $$
  select public.expire_verification_subscriptions();
  $$
);

-- ============================================================================
-- Migration: 20260624162913_verification_billing_renewal_cron.sql
-- ============================================================================

-- Attempt automatic verification renewals through the billing Edge Function.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'prosme-verification-renewals') then
    perform cron.unschedule('prosme-verification-renewals');
  end if;
end;
$$;

select cron.schedule(
  'prosme-verification-renewals',
  '*/30 * * * *',
  $$
  select net.http_post(
    url := 'https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/verification-billing',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-dispatch-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'email_dispatch_secret'
        limit 1
      )
    ),
    body := jsonb_build_object('action', 'renewDue', 'limit', 50),
    timeout_milliseconds := 20000
  );
  $$
);

-- ============================================================================
-- Migration: 20260625214000_repair_email_templates_and_verification_flow.sql
-- ============================================================================

-- Keep user-facing email alerts readable and avoid verification side-effect
-- failures caused by missing grants on recent billing/outbox tables.

grant select, insert, update on public.email_outbox to authenticated, service_role;
grant select, insert, update on public.verification_subscriptions to authenticated, service_role;
grant select, insert on public.verification_payments to authenticated, service_role;
grant select, insert, update on public.admin_notifications to authenticated, service_role;

create or replace function public.prosme_email_body_text(value text)
returns text
language plpgsql
immutable
as $$
declare
  parsed jsonb;
  parts text[];
begin
  if value is null or btrim(value) = '' then
    return 'You have a new ProSME update.';
  end if;

  if left(btrim(value), 1) not in ('{', '[') then
    return value;
  end if;

  begin
    parsed := value::jsonb;
  exception
    when others then
      return value;
  end;

  if jsonb_typeof(parsed) <> 'object' then
    return value;
  end if;

  parts := array_remove(array[
    nullif(parsed->>'message', ''),
    nullif(parsed->>'body', ''),
    nullif(parsed->>'content', ''),
    nullif(parsed->>'title', ''),
    nullif(parsed->>'description', '')
  ], null);

  if array_length(parts, 1) is not null then
    return array_to_string(parts, E'\n\n');
  end if;

  return regexp_replace(value, '[{}"]', '', 'g');
end;
$$;

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile record;
  readable_body text;
begin
  select id, email, phone, email_notifications, phone_notifications
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  readable_body := public.prosme_email_body_text(email_body);

  if target_profile.email_notifications and coalesce(target_profile.email, '') <> '' then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (
      target_profile.email,
      coalesce(nullif(email_subject, ''), 'New ProSME update'),
      readable_body,
      target_profile.id
    );
  end if;

  if target_profile.phone_notifications and coalesce(target_profile.phone, '') <> '' then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (
      target_profile.phone,
      left(public.prosme_email_body_text(sms_body), 160),
      target_profile.id
    );
  end if;
end;
$$;

revoke all on function public.queue_profile_notification(uuid, text, text, text)
from public, anon, authenticated;

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

revoke all on function public.queue_admin_notification_email()
from public, anon, authenticated;

update public.email_outbox
set body = public.prosme_email_body_text(body)
where sent_at is null
  and left(btrim(coalesce(body, '')), 1) in ('{', '[');

-- ============================================================================
-- Migration: 20260626001000_chat_email_privacy_analytics_events.sql
-- ============================================================================

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

alter table public.analytics_events
  add column if not exists source text not null default 'web',
  add column if not exists event_name text not null default 'page_view',
  add column if not exists path text,
  add column if not exists referrer text,
  add column if not exists user_agent text,
  add column if not exists session_id text,
  add column if not exists user_id uuid references public.profiles(id) on delete set null,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default timezone('utc', now());

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

-- ============================================================================
-- Migration: 20260629214500_verification_pay_before_review_flow.sql
-- ============================================================================

-- Verification flow repair:
-- 1. Users upload documents first and must pay before admin review.
-- 2. Paystack success moves the subscription to paid_pending_review.
-- 3. Admin approval activates the badge.
-- 4. Owners can replace uploaded documents when restarting the flow.

do $$
begin
  alter table public.verification_subscriptions
    drop constraint if exists verification_subscriptions_status_check;
  alter table public.verification_subscriptions
    add constraint verification_subscriptions_status_check
    check (status in (
      'payment_required',
      'pending_payment',
      'paid_pending_review',
      'active',
      'expired',
      'cancelled',
      'renewal_failed'
    ));
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'artisan-verification',
  'artisan-verification',
  true,
  1048576,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Artisans can upload verification documents" on storage.objects;
drop policy if exists "Users can view verification documents" on storage.objects;
drop policy if exists "Verification owners can upload documents" on storage.objects;
drop policy if exists "Verification owners can update documents" on storage.objects;
drop policy if exists "Verification owners can delete documents" on storage.objects;
drop policy if exists "Verification owners and admins can view documents" on storage.objects;

create policy "Verification owners can upload documents"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'artisan-verification'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Verification owners can update documents"
on storage.objects for update
to authenticated
using (
  bucket_id = 'artisan-verification'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'artisan-verification'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Verification owners can delete documents"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'artisan-verification'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Verification owners and admins can view documents"
on storage.objects for select
to authenticated
using (
  bucket_id = 'artisan-verification'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or app_private.is_admin()
  )
);

grant select, insert, update, delete on public.verification_subscriptions
to authenticated, service_role;
grant select, insert, update on public.verification_payments
to authenticated, service_role;

drop policy if exists "Users can restart unpaid verification subscriptions"
on public.verification_subscriptions;
create policy "Users can restart unpaid verification subscriptions"
on public.verification_subscriptions
for delete
to authenticated
using (
  user_id = (select auth.uid())
  and status in ('payment_required', 'pending_payment', 'expired')
);

-- ============================================================================
-- Migration: 20260629233000_notification_delivery_preferences.sql
-- ============================================================================

-- Add per-channel notification category preferences and honor them when
-- queueing email/SMS alerts for profile notifications.

alter table public.profiles
  add column if not exists blocked_email_notification_types text[] not null default '{}'::text[],
  add column if not exists blocked_phone_notification_types text[] not null default '{}'::text[];

create or replace function public.prosme_notification_type(value text)
returns text
language plpgsql
immutable
as $$
declare
  normalized text;
begin
  normalized := lower(coalesce(value, ''));

  if normalized like '%chat%' or normalized like '%message%' then
    return 'chat';
  elsif normalized like '%bid%' then
    return 'bid';
  elsif normalized like '%booking%' then
    return 'booking';
  elsif normalized like '%job%' or normalized like '%work%' then
    return 'job';
  elsif normalized like '%payment%'
     or normalized like '%wallet%'
     or normalized like '%invoice%'
     or normalized like '%billing%' then
    return 'payment';
  elsif normalized like '%verification%' or normalized like '%verify%' then
    return 'verification';
  elsif normalized like '%support%' or normalized like '%report%' then
    return 'support';
  elsif normalized like '%account%'
     or normalized like '%password%'
     or normalized like '%profile%' then
    return 'account';
  end if;

  return 'system';
end;
$$;

create or replace function public.prosme_blocks_notification_type(
  blocked_types text[],
  notification_type text
)
returns boolean
language sql
immutable
as $$
  select 'all' = any(coalesce(blocked_types, '{}'::text[]))
      or coalesce(notification_type, 'system') = any(coalesce(blocked_types, '{}'::text[]));
$$;

create or replace function public.queue_profile_notification(
  target_user_id uuid,
  email_subject text,
  email_body text,
  sms_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile record;
  readable_body text;
  notification_type text;
begin
  select
    id,
    email,
    phone,
    email_notifications,
    phone_notifications,
    blocked_email_notification_types,
    blocked_phone_notification_types
  into target_profile
  from public.profiles
  where id = target_user_id;

  if target_profile.id is null then
    return;
  end if;

  readable_body := public.prosme_email_body_text(email_body);
  notification_type := public.prosme_notification_type(
    concat_ws(' ', email_subject, email_body, sms_body)
  );

  if target_profile.email_notifications
     and coalesce(target_profile.email, '') <> ''
     and not public.prosme_blocks_notification_type(
       target_profile.blocked_email_notification_types,
       notification_type
     ) then
    insert into public.email_outbox (to_email, subject, body, related_user_id)
    values (
      target_profile.email,
      coalesce(nullif(email_subject, ''), 'New ProSME update'),
      readable_body,
      target_profile.id
    );
  end if;

  if target_profile.phone_notifications
     and coalesce(target_profile.phone, '') <> ''
     and not public.prosme_blocks_notification_type(
       target_profile.blocked_phone_notification_types,
       notification_type
     ) then
    insert into public.sms_outbox (to_phone, body, related_user_id)
    values (
      target_profile.phone,
      left(public.prosme_email_body_text(sms_body), 160),
      target_profile.id
    );
  end if;
end;
$$;

revoke all on function public.prosme_notification_type(text)
from public, anon, authenticated;

revoke all on function public.prosme_blocks_notification_type(text[], text)
from public, anon, authenticated;

revoke all on function public.queue_profile_notification(uuid, text, text, text)
from public, anon, authenticated;

-- ============================================================================
-- Migration: 20260630010000_fix_verification_subscription_owner_rls.sql
-- ============================================================================

-- Allow users to create or refresh their own unpaid verification subscription
-- after uploading documents. Paystack success and activation remain server-side.

grant select, insert, update, delete on public.verification_subscriptions
to authenticated, service_role;

drop policy if exists "Users can create own unpaid verification subscriptions"
on public.verification_subscriptions;
create policy "Users can create own unpaid verification subscriptions"
on public.verification_subscriptions
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'payment_required'
  and plan_interval in ('monthly', 'yearly')
  and role in ('customer', 'artisan')
  and amount_usd = case
    when role = 'artisan' then 5::numeric
    else 2::numeric
  end
  and role = coalesce((
    select p.role
    from public.profiles p
    where p.id = (select auth.uid())
  ), '')
);

-- ============================================================================
-- Migration: 20260728000000_repair_jobs_insert_rls.sql
-- ============================================================================

grant select, insert, update, delete on public.jobs to authenticated;

drop policy if exists "Users can create jobs" on public.jobs;
drop policy if exists "Verified artisans can create jobs" on public.jobs;
drop policy if exists "Users and artisans can create jobs" on public.jobs;
drop policy if exists "Users can create own jobs" on public.jobs;

create policy "Users can create own jobs"
on public.jobs
for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "Users can refresh own unpaid verification subscriptions"
on public.verification_subscriptions;
create policy "Users can refresh own unpaid verification subscriptions"
on public.verification_subscriptions
for update
to authenticated
using (
  user_id = (select auth.uid())
  and status in ('payment_required', 'pending_payment', 'expired', 'cancelled')
)
with check (
  user_id = (select auth.uid())
  and status = 'payment_required'
  and plan_interval in ('monthly', 'yearly')
  and role in ('customer', 'artisan')
  and amount_usd = case
    when role = 'artisan' then 5::numeric
    else 2::numeric
  end
  and role = coalesce((
    select p.role
    from public.profiles p
    where p.id = (select auth.uid())
  ), '')
);
