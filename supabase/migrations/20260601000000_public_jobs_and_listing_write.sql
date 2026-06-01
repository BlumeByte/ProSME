-- Public marketplace feeds. Inserts still require authenticated owners.
drop policy if exists "Public can read jobs" on public.jobs;
create policy "Public can read jobs"
on public.jobs for select
to anon, authenticated
using (true);

drop policy if exists "Public can read profiles" on public.profiles;
create policy "Public can read profiles"
on public.profiles for select
to anon, authenticated
using (true);
