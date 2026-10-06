-- Bulk account import from an Excel sheet (admin dashboard).
--
-- account_source  'self' for people who signed up themselves, 'imported' for
--                 accounts created by an admin from a spreadsheet.
-- imported_at     when the admin import created the account.
-- redeemed_at     first time the imported person signed in (set by the app),
--                 i.e. they followed the emailed link and chose a password.

alter table public.profiles
  add column if not exists account_source text not null default 'self'
    check (account_source in ('self', 'imported')),
  add column if not exists imported_at timestamptz,
  add column if not exists redeemed_at timestamptz;

-- Counts shown on the admin dashboard. Only admins may call it.
create or replace function public.admin_import_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app_private.is_admin() then
    raise exception 'Only admins can view import statistics.' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'total', count(*),
      'redeemed', count(*) filter (
        where p.redeemed_at is not null or u.last_sign_in_at is not null
      ),
      'pending', count(*) filter (
        where p.redeemed_at is null and u.last_sign_in_at is null
      ),
      'artisans', count(*) filter (where p.role = 'artisan'),
      'customers', count(*) filter (where p.role = 'customer'),
      'last_imported_at', max(p.imported_at)
    )
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.account_source = 'imported'
  );
end;
$$;

revoke all on function public.admin_import_stats() from public, anon;
grant execute on function public.admin_import_stats() to authenticated;
