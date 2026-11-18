# Deploy ProSME Admin Dashboard to Vercel

This repository now contains a Vercel-ready web dashboard at `admin_web`.

## Recommended Vercel Import Settings

- **Framework Preset:** Vite
- **Root Directory:** `admin_web`
- **Build Command:** `npm run build`
- **Output Directory:** `dist`
- **Install Command:** `npm install`
- **Production Domain:** `prosme.blumebyte.com`

## Required Environment Variables

Add these in Vercel under **Project Settings > Environment Variables**:

```text
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-or-anon-key
```

Use the Supabase publishable key, or the legacy anon key if your project still uses legacy keys. Do not use the service role key in this web dashboard.

## Admin Login

Create `blumebyte@gmail.com` in Supabase Auth with your chosen password, then run this SQL in Supabase SQL Editor:

```sql
update public.profiles
set role = 'admin',
    verification_status = 'verified',
    full_name = coalesce(full_name, 'BlumeByte Admin'),
    email = 'blumebyte@gmail.com'
where email = 'blumebyte@gmail.com';
```

If no row updates, create the profile row:

```sql
insert into public.profiles (id, email, full_name, role, verification_status)
select id, email, 'BlumeByte Admin', 'admin', 'verified'
from auth.users
where email = 'blumebyte@gmail.com'
on conflict (id) do update
set role = 'admin',
    verification_status = 'verified',
    full_name = excluded.full_name,
    email = excluded.email;
```

## Local Test

```powershell
cd admin_web
copy .env.example .env.local
npm install
npm run dev
```

Fill `.env.local` before running locally.

## Production URLs

Configure Supabase Auth with `https://prosme.blumebyte.com` as the Site URL and add these redirect URLs:

```text
https://prosme.blumebyte.com/reset-password
https://prosme.vercel.app/reset-password
https://pro-sme.vercel.app/reset-password
com.prosme.app://login-callback
```

Verify `prosme.blumebyte.com` in Resend before using `ProSME <noreply@prosme.blumebyte.com>` as the production sender.

Add this Paystack webhook URL in Paystack Dashboard > Settings > API Keys & Webhooks:

```text
https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/verification-billing
```

## Preview integration credentials

The Vercel build uses a Supabase project URL and a public client key. Supabase
Edge Functions obtain privileged credentials from their own runtime.

Remove unused preview-scoped database credentials and privileged Supabase keys
from Vercel after verifying the branch has no server-side consumer. Database
connection URLs that contain passwords are credentials too. If a server-side
consumer needs a credential, restrict its environment scope and store it as
Sensitive. Keep publishable or legacy anon keys in browser configuration.

Removing a variable does not retroactively change older deployments. Rebuild
any preview you intend to keep. If a database credential or privileged key was
exposed, rotate it at Supabase and update its dependent services. Coordinate
legacy JWT secret rotation separately because it can invalidate existing keys
and user sessions.
