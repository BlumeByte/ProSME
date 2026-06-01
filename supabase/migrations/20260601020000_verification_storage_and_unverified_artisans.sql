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
