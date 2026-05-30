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
