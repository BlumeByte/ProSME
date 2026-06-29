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
