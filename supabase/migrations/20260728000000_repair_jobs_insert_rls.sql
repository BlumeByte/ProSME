grant select, insert, update, delete on public.jobs to authenticated;

drop policy if exists "Users can create jobs" on public.jobs;
drop policy if exists "Verified artisans can create jobs" on public.jobs;
drop policy if exists "Users and artisans can create jobs" on public.jobs;
drop policy if exists "Users can create own jobs" on public.jobs;

create policy "Users can create own jobs"
on public.jobs
for insert
to authenticated
with check (created_by = (select auth.uid()));
