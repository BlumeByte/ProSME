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
