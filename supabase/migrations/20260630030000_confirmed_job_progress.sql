alter table public.jobs
drop constraint if exists jobs_work_status_check;

alter table public.jobs
add constraint jobs_work_status_check
check (
  work_status in (
    'open',
    'accepted',
    'start_pending',
    'in_progress',
    'completion_pending',
    'completed',
    'cancelled'
  )
);

alter table public.job_status_events
drop constraint if exists job_status_events_status_check;

alter table public.job_status_events
add constraint job_status_events_status_check
check (
  status in (
    'open',
    'accepted',
    'start_pending',
    'in_progress',
    'completion_pending',
    'completed',
    'cancelled'
  )
);

create or replace function public.update_job_progress(
  p_job_id uuid,
  p_status text,
  p_eta_at timestamptz default null,
  p_note text default null
)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  current_job public.jobs%rowtype;
  accepted_artisan uuid;
  actor_role text;
  next_status text := lower(trim(coalesce(p_status, '')));
  is_owner boolean;
  is_artisan boolean;
  is_admin boolean;
  target_user uuid;
  notification_title text;
  notification_body text;
begin
  if actor is null then
    raise exception 'Authentication required';
  end if;
  if next_status not in (
    'accepted',
    'start_pending',
    'in_progress',
    'completion_pending',
    'completed',
    'cancelled'
  ) then
    raise exception 'Invalid job status';
  end if;

  select * into current_job
  from public.jobs
  where id = p_job_id
  for update;
  if current_job.id is null then
    raise exception 'Job not found';
  end if;

  select b.artisan_id into accepted_artisan
  from public.job_bids b
  where b.job_id = p_job_id and b.status = 'accepted'
  order by b.updated_at desc nulls last, b.created_at desc
  limit 1;
  select p.role into actor_role from public.profiles p where p.id = actor;

  is_owner := actor = current_job.created_by;
  is_artisan := actor is not distinct from accepted_artisan;
  is_admin := coalesce(actor_role, '') = 'admin';

  if not (is_owner or is_artisan or is_admin) then
    raise exception 'Only job participants can update progress';
  end if;
  if accepted_artisan is null and next_status <> 'cancelled' then
    raise exception 'Accept a bid before updating progress';
  end if;
  if current_job.work_status = 'completed' and next_status <> 'completed' then
    raise exception 'Completed jobs cannot be reopened';
  end if;
  if current_job.work_status = 'cancelled' then
    raise exception 'Cancelled jobs cannot be updated';
  end if;

  if next_status = current_job.work_status then
    -- Same-status updates are for ETA or note changes by either participant.
    null;
  elsif next_status = 'start_pending' then
    if not (is_artisan or is_admin) then
      raise exception 'Only the accepted artisan can request work start confirmation';
    end if;
    if current_job.work_status <> 'accepted' then
      raise exception 'Work can only be started after bid acceptance';
    end if;
    target_user := current_job.created_by;
    notification_title := 'Work start confirmation requested';
    notification_body := 'The artisan says work is ready to begin. Please confirm on the job details page.';
  elsif next_status = 'in_progress' then
    if not (is_owner or is_admin) then
      raise exception 'Only the customer can confirm work has started';
    end if;
    if current_job.work_status <> 'start_pending' then
      raise exception 'The artisan must request start confirmation first';
    end if;
    target_user := accepted_artisan;
    notification_title := 'Work start confirmed';
    notification_body := 'The customer confirmed that work has started.';
  elsif next_status = 'completion_pending' then
    if not (is_artisan or is_admin) then
      raise exception 'Only the accepted artisan can request completion confirmation';
    end if;
    if current_job.work_status <> 'in_progress' then
      raise exception 'Work must be in progress before completion can be requested';
    end if;
    target_user := current_job.created_by;
    notification_title := 'Completion confirmation requested';
    notification_body := 'The artisan marked the work as completed. Please confirm, then rate or comment on the work.';
  elsif next_status = 'completed' then
    if not (is_owner or is_admin) then
      raise exception 'Only the customer can confirm completion';
    end if;
    if current_job.work_status <> 'completion_pending' then
      raise exception 'The artisan must request completion confirmation first';
    end if;
    target_user := accepted_artisan;
    notification_title := 'Work completed';
    notification_body := 'The customer confirmed the work is completed.';
  else
    raise exception 'Invalid job status transition';
  end if;

  update public.jobs
  set work_status = next_status,
      eta_at = coalesce(p_eta_at, eta_at),
      started_at = case
        when next_status = 'in_progress' then coalesce(started_at, timezone('utc', now()))
        else started_at
      end,
      completed_at = case
        when next_status = 'completed' then coalesce(completed_at, timezone('utc', now()))
        else completed_at
      end,
      status_updated_at = timezone('utc', now()),
      status = case
        when next_status = 'completed' then 'completed'
        when next_status = 'cancelled' then 'cancelled'
        else 'active'
      end
  where id = p_job_id
  returning * into current_job;

  insert into public.job_status_events (job_id, actor_id, status, note, eta_at)
  values (
    p_job_id,
    actor,
    next_status,
    nullif(trim(coalesce(p_note, '')), ''),
    current_job.eta_at
  );

  if target_user is not null then
    insert into public.admin_notifications (
      type,
      title,
      body,
      actor_id,
      related_user_id,
      related_table,
      related_id
    ) values (
      'job_progress',
      notification_title,
      notification_body,
      actor,
      target_user,
      'jobs',
      p_job_id
    );
  end if;

  if next_status = 'completed' and current_job.accepted_bid_id is not null then
    perform public.sync_wallet_transaction_for_bid(current_job.accepted_bid_id, 'completed');
  end if;
  return current_job;
end;
$$;

revoke all on function public.update_job_progress(uuid, text, timestamptz, text)
from public, anon;
grant execute on function public.update_job_progress(uuid, text, timestamptz, text)
to authenticated;
