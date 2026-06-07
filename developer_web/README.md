# ProSME Developer Web Dashboard

This is the Vercel-ready web dashboard for ProSME admins and developers.

## Vercel Setup

1. Push this repository to GitHub.
2. In Vercel, import the GitHub repository.
3. Set **Root Directory** to `developer_web`.
4. Select **Framework Preset**: `Vite`.
5. Add these Environment Variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
6. Deploy.

Do not add a Supabase `service_role` or secret key here. This dashboard runs in the browser, so it must use the publishable or anon key and rely on Supabase Row Level Security.

## Local Run

```powershell
npm install
npm run dev
```

## Developer Account

Create or sign up the developer user in Supabase Auth, then run:

```sql
update public.profiles
set role = 'developer',
    verification_status = 'verified',
    full_name = coalesce(full_name, 'BlumeByte Developer'),
    email = 'blumebyte@gmail.com'
where email = 'blumebyte@gmail.com';
```

The dashboard only allows users with `admin` or `developer` role to continue after login.
