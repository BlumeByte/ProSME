# Deploy ProSME Developer Dashboard to Vercel

This repository now contains a Vercel-ready web dashboard at `developer_web`.

## Recommended Vercel Import Settings

- **Framework Preset:** Vite
- **Root Directory:** `developer_web`
- **Build Command:** `npm run build`
- **Output Directory:** `dist`
- **Install Command:** `npm install`

## Required Environment Variables

Add these in Vercel under **Project Settings > Environment Variables**:

```text
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-or-anon-key
```

Use the Supabase publishable key, or the legacy anon key if your project still uses legacy keys. Do not use the service role key in this web dashboard.

## Developer Login

Create `blumebyte@gmail.com` in Supabase Auth with your chosen password, then run this SQL in Supabase SQL Editor:

```sql
update public.profiles
set role = 'developer',
    verification_status = 'verified',
    full_name = coalesce(full_name, 'BlumeByte Developer'),
    email = 'blumebyte@gmail.com'
where email = 'blumebyte@gmail.com';
```

If no row updates, create the profile row:

```sql
insert into public.profiles (id, email, full_name, role, verification_status)
select id, email, 'BlumeByte Developer', 'developer', 'verified'
from auth.users
where email = 'blumebyte@gmail.com'
on conflict (id) do update
set role = 'developer',
    verification_status = 'verified',
    full_name = excluded.full_name,
    email = excluded.email;
```

## Local Test

```powershell
cd developer_web
copy .env.example .env.local
npm install
npm run dev
```

Fill `.env.local` before running locally.
