-- Profile PII, part 2: column-level lock-down.
--
-- !! DO NOT APPLY until BOTH are true:
--    1. Every installed ProSME app is on build 1.0.26+27 or newer (it reads the
--       caller's own profile via get_my_profile() and the admin screens via
--       admin_list_profiles(), and no longer selects `email` for other users).
--       Older builds select e-mail/phone/etc. directly and would fail to load
--       profiles after this runs.
--    2. admin_web has been redeployed with the same RPC changes.
--
-- Until then any signed-in user can read every other user's e-mail, phone, date
-- of birth, gender, mobile-money number and verification-document paths.
--
-- After this runs, clients can read only the public marketplace columns of
-- profiles. Writes are unaffected (table-level INSERT/UPDATE stay, and the
-- profiles_guard_write trigger still enforces what users may change).

revoke select on public.profiles from authenticated;

grant select (id, username, full_name, avatar_url, role, verification_status,
              verification_expires_at, is_busy, description, country,
              country_code, categories, location, bio, rating_summary,
              created_at, updated_at)
  on public.profiles to authenticated;
