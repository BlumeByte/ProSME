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
