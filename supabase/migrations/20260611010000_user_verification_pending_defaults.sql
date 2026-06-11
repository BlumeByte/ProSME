alter table public.profiles
  alter column verification_status set default 'pending';

update public.profiles
set verification_status = 'pending'
where coalesce(role, 'customer') <> 'artisan'
  and verification_status = 'verified'
  and coalesce(national_id_front_url, national_id_url, '') = ''
  and coalesce(national_id_back_url, '') = '';
