alter table public.profiles
add column if not exists username text;

update public.profiles
set username = 'user_' || left(replace(id::text, '-', ''), 8)
where username is null or btrim(username) = '';

create unique index if not exists profiles_username_unique_idx
on public.profiles (lower(username));

create unique index if not exists profiles_email_unique_idx
on public.profiles (lower(email))
where email is not null and btrim(email) <> '';

drop policy if exists "Public can read listings" on public.listings;
create policy "Public can read listings"
on public.listings for select
to anon, authenticated
using (true);

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;
