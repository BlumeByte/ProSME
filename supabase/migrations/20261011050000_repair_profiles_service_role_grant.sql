-- Repair Data API grants needed by ProSME server-side admin imports.
-- The admin-dashboard Edge Function uses the service_role client to create
-- and then upsert imported profiles. RLS bypass is not enough when the
-- underlying table privilege is missing; PostgREST returns:
--   permission denied for table profiles
--
-- Keep this narrowly scoped to the server role. Client grants are unchanged.

grant usage on schema public to service_role;
grant select, insert, update, delete on table public.profiles to service_role;
