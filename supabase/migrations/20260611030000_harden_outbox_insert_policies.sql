drop policy if exists "Users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create email tasks" on public.email_outbox;
drop policy if exists "Authenticated users can create limited email tasks" on public.email_outbox;
create policy "Authenticated users can create limited email tasks"
on public.email_outbox for insert
to authenticated
with check (
  (
    related_user_id = (select auth.uid())
    and (
      to_email is null
      or lower(to_email) = 'blumebyte@gmail.com'
    )
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Authenticated users can create sms tasks" on public.sms_outbox;
drop policy if exists "Authenticated users can create own sms tasks" on public.sms_outbox;
create policy "Authenticated users can create own sms tasks"
on public.sms_outbox for insert
to authenticated
with check (
  related_user_id = (select auth.uid())
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'admin')
  )
);
