alter table public.profiles
  add column if not exists gender text,
  add column if not exists date_of_birth date;

alter table public.profiles
  drop constraint if exists profiles_gender_check,
  add constraint profiles_gender_check
  check (
    gender is null
    or gender in ('female', 'male', 'non_binary', 'prefer_not_to_say')
  );

alter table public.profiles
  drop constraint if exists profiles_date_of_birth_adult_check,
  add constraint profiles_date_of_birth_adult_check
  check (
    date_of_birth is null
    or date_of_birth <= current_date - interval '18 years'
  );

alter table public.jobs
  add column if not exists deleted_by_user_at timestamptz,
  add column if not exists deleted_by_user_reason text;

create index if not exists jobs_deleted_by_user_at_idx
on public.jobs (deleted_by_user_at)
where deleted_by_user_at is not null;
