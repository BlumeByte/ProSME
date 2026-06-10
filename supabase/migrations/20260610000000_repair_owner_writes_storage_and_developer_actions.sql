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
