create table if not exists public.chat_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  thread_id uuid references public.threads(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_user_id)
);

alter table public.chat_blocks enable row level security;
grant select, insert, delete on public.chat_blocks to authenticated;
revoke select, insert, update, delete on public.chat_blocks from anon;

drop policy if exists "Users can create own chat blocks" on public.chat_blocks;
create policy "Users can create own chat blocks"
on public.chat_blocks for insert
to authenticated
with check (blocker_id = (select auth.uid()));

drop policy if exists "Users can read own chat blocks" on public.chat_blocks;
create policy "Users can read own chat blocks"
on public.chat_blocks for select
to authenticated
using (
  blocker_id = (select auth.uid())
  or blocked_user_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists "Users can delete own chat blocks" on public.chat_blocks;
create policy "Users can delete own chat blocks"
on public.chat_blocks for delete
to authenticated
using (blocker_id = (select auth.uid()) or app_private.is_admin());

do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_blocks'
  ) then
    null;
  else
    alter publication supabase_realtime add table public.chat_blocks;
  end if;
exception
  when undefined_object then
    null;
end;
$$;
