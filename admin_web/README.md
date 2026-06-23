# ProSME Admin Web Dashboard

This is the Vercel-ready web dashboard for ProSME admins.

## Vercel Setup

1. Push this repository to GitHub.
2. In Vercel, import the GitHub repository.
3. Set **Root Directory** to `admin_web`.
4. Select **Framework Preset**: `Vite`.
5. Add these Environment Variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
6. Deploy.

Do not add a Supabase `service_role` or secret key to Vercel. This dashboard runs in the browser, so it must use only the publishable or anon key and rely on Supabase Row Level Security.

## Supabase Setup

Apply the migrations in `supabase/migrations`, then deploy the admin dashboard Edge Function:

```powershell
supabase functions deploy admin-dashboard
supabase secrets set SUPABASE_URL="https://your-project-ref.supabase.co"
supabase secrets set SUPABASE_ANON_KEY="your-publishable-or-anon-key"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
supabase secrets set PASSWORD_RESET_REDIRECT_URL="https://your-vercel-domain.vercel.app/reset-password"
supabase secrets set RESEND_API_KEY="your-resend-api-key"
supabase secrets set RESEND_FROM_EMAIL="ProSME <noreply@your-verified-domain.com>"
```

Use the same Supabase project for Vercel and the Edge Function. For example, if your function URL is `https://ivohczdtuxasyfoiphqu.supabase.co/functions/v1/admin-dashboard`, then Vercel's `VITE_SUPABASE_URL` and the function secret `SUPABASE_URL` must both be `https://ivohczdtuxasyfoiphqu.supabase.co`.

The `SUPABASE_SERVICE_ROLE_KEY` belongs in Supabase Function secrets only. It is used for admin-only actions such as creating accounts, generating recovery links, and setting temporary passwords. Password recovery first uses the Supabase Auth mailer and falls back to Resend when its secrets are configured. Add `https://your-vercel-domain.vercel.app/reset-password` to the Supabase Auth redirect URL allow list.

## Local Run

```powershell
npm install
npm run dev
```

## Admin Account

Create or sign up the admin user in Supabase Auth, then run:

```sql
update public.profiles
set role = 'admin',
    verification_status = 'verified',
    full_name = coalesce(full_name, 'BlumeByte Admin'),
    email = 'blumebyte@gmail.com'
where email = 'blumebyte@gmail.com';
```

The dashboard only allows users with `admin` role to continue after login. Admin, artisan, and customer accounts are signed out immediately.
