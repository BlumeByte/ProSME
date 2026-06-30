create or replace function public.prevent_locked_job_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  locked boolean;
begin
  locked :=
    old.accepted_bid_id is not null
    or old.accepted_amount is not null
    or coalesce(old.work_status, 'open') <> 'open'
    or coalesce(old.status, 'open') in ('active', 'completed');

  if not locked then
    return new;
  end if;

  if old.title is distinct from new.title
    or old.description is distinct from new.description
    or old.location is distinct from new.location
    or old.budget is distinct from new.budget
    or old.images is distinct from new.images
    or old.location_lat is distinct from new.location_lat
    or old.location_lng is distinct from new.location_lng
    or old.location_source is distinct from new.location_source then
    raise exception 'Accepted jobs cannot be edited.';
  end if;

  return new;
end;
$$;

drop trigger if exists jobs_prevent_locked_changes on public.jobs;
create trigger jobs_prevent_locked_changes
before update on public.jobs
for each row execute function public.prevent_locked_job_changes();

create or replace function public.prevent_locked_job_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.accepted_bid_id is not null
    or old.accepted_amount is not null
    or coalesce(old.work_status, 'open') <> 'open'
    or coalesce(old.status, 'open') in ('active', 'completed') then
    raise exception 'Accepted jobs cannot be deleted.';
  end if;

  return old;
end;
$$;

drop trigger if exists jobs_prevent_locked_delete on public.jobs;
create trigger jobs_prevent_locked_delete
before delete on public.jobs
for each row execute function public.prevent_locked_job_delete();

revoke all on function public.prevent_locked_job_changes() from public, anon, authenticated;
revoke all on function public.prevent_locked_job_delete() from public, anon, authenticated;
