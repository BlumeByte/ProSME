# ProSME

ProSME is a lightweight Flutter marketplace for connecting customers with verified SMEs and artisans. It supports quick registration, chat, invoices, payments, job tracking, and an admin dashboard designed for low-literacy users.

## Features
- **Three roles**: Customer, Artisan, Admin
- **Simple onboarding** with role selection and artisan verification flow
- **Listing feed** with search and category chips
- **Listing details** with image carousel, map preview, and quick actions
- **Realtime chat** (mock + Supabase Realtime ready)
- **Invoice workflow** for accepted bids, with branded PDF print/share and artisan-to-customer chat delivery
- **Job tracking** with participant updates, progress notes, durable timelines, ETA, and completion syncing to Wallet
- **AI support** with categorized FAQ search, guided answers, support responses, and ticket escalation

## Tech Stack
- Flutter (stable)
- State management: Riverpod
- Routing: go_router
- Local DB (offline-first): Drift (stubbed service ready)
- Cloud sync/auth: Supabase Auth + Postgres + Realtime
- Notifications: flutter_local_notifications (foreground) + Firebase Cloud Messaging (background/terminated push)
- Payments: Paystack (via URL launch / WebView)
- Maps: google_maps_flutter

## Project Structure
```
lib/
  app.dart
  main.dart
  config/
  core/
  models/
  routes/
  services/
  features/
    onboarding/
    auth/
    home/
    listing/
    chat/
    invoice/
    jobs/
    saved/
    profile/
    admin/
    support/
```

## Setup

### 1) Install dependencies
```bash
flutter pub get
```

### 2) Supabase setup
1. Create a Supabase project.
2. Enable Authentication providers you need (Email, Google, Microsoft/Azure, Phone/OTP if implemented).
   - For Microsoft: register an app in [Azure Portal](https://portal.azure.com) (App registrations), add
     `https://<your-project>.supabase.co/auth/v1/callback` as a redirect URI, then paste the
     Application (client) ID and a client secret into Supabase Dashboard -> Authentication -> Sign In / Providers -> Azure.
3. Apply migration SQL:
   - Run every file in `supabase/migrations/` in timestamp order.
   - Password recovery specifically requires `20260623135621_password_recovery_rate_limit.sql`.
4. For Google/Microsoft OAuth and password recovery, add these redirect URLs in Supabase Auth settings:
   - `<your.android.applicationId>://login-callback`
   - `com.blumebyte.prosme://login-callback`
   - `https://prosme.blumebyte.com/reset-password`
   - `https://prosme.vercel.app/reset-password`
   - `https://pro-sme.vercel.app/reset-password`
5. Deploy the password recovery function and configure the existing Resend account:
   ```powershell
   npx supabase functions deploy password-recovery --project-ref <your-project-ref>
   npx supabase secrets set PASSWORD_RESET_REDIRECT_URL="https://prosme.blumebyte.com/reset-password" PASSWORD_RESET_ALLOWED_REDIRECTS="com.blumebyte.prosme://login-callback,https://prosme.blumebyte.com/reset-password,https://prosme.vercel.app/reset-password,https://pro-sme.vercel.app/reset-password" --project-ref <your-project-ref>
   npx supabase secrets set RESEND_API_KEY="<your-resend-key>" RESEND_FROM_EMAIL="ProSME <noreply@prosme.blumebyte.com>" --project-ref <your-project-ref>
   ```
   The `prosme.blumebyte.com` sender domain must be verified in Resend before switching `RESEND_FROM_EMAIL` to `noreply@prosme.blumebyte.com`.
6. Add runtime defines when running the app:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
     --dart-define=GOOGLE_OAUTH_REDIRECT_URL=<your.android.applicationId>://login-callback \
     --dart-define=MICROSOFT_OAUTH_REDIRECT_URL=<your.android.applicationId>://login-callback \
     --dart-define=PASSWORD_RECOVERY_REDIRECT_URL=<your.android.applicationId>://login-callback
   ```
   Or create a local ignored `supabase.local.json` from `supabase.local.example.json` and run:
   ```bash
   flutter run --dart-define-from-file=supabase.local.json
   ```
7. Verify realtime feed:
   - Open one signed-in client and keep listings/chat/jobs screens open.
   - Insert/update rows in `listings`, `messages`, or `jobs`.
   - Confirm the app stream updates without restart.

### 3) Push notifications (Firebase)
Local notifications (`flutter_local_notifications`) only fire while the app is open. Background and
terminated-app push go through Firebase Cloud Messaging, drained server-side by the `send-push-outbox`
edge function every time a priority notification (bid, booking, job, or account) is queued.
1. Create or reuse a project at [Firebase Console](https://console.firebase.google.com).
2. From the repo root, run `flutterfire configure` and select that project. This overwrites
   `lib/firebase_options.dart` with real values and adds `android/app/google-services.json` +
   `ios/Runner/GoogleService-Info.plist`. Until this runs, push stays silently disabled — nothing else breaks.
3. In Firebase Console -> Project settings -> Service accounts, generate a new private key (JSON).
4. Deploy the dispatch function and set its secrets from that JSON:
   ```powershell
   npx supabase functions deploy send-push-outbox --project-ref wbnvifrzckjttyxhmlcf
   npx supabase secrets set FIREBASE_PROJECT_ID="<project_id from the JSON>" FIREBASE_CLIENT_EMAIL="<client_email from the JSON>" FIREBASE_PRIVATE_KEY="<private_key from the JSON>" --project-ref wbnvifrzckjttyxhmlcf
   ```
5. iOS also needs an APNs authentication key uploaded in Firebase Console -> Project settings -> Cloud Messaging.
6. Verify: sign in on a real device, accept/progress a job as the other party, and confirm a system
   notification arrives even with the app closed. Rows land in `public.push_outbox` either way — check
   `last_error` there if nothing arrives.

### 4) Enable Google Maps
1. Get a Google Maps API key.
2. Android: set in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
     android:name="com.google.android.geo.API_KEY"
     android:value="YOUR_API_KEY" />
   ```
3. iOS: set in `ios/Runner/AppDelegate.swift` and `Info.plist`.
4. Web: configure in `web/index.html`.

### 5) Paystack setup
- Use Paystack’s hosted checkout URL for MoMo.
- Update the Paystack public key in your payment service if needed.
- Add the production webhook URL in Paystack Dashboard > Settings > API Keys & Webhooks:
  `https://wbnvifrzckjttyxhmlcf.supabase.co/functions/v1/verification-billing`

### 6) Run the app
```bash
flutter run
```

## Dev Mode
`kMockMode` is controlled with `--dart-define=MOCK_MODE=true`. Without it, the app attempts Supabase initialization and falls back to mocks if Supabase is unavailable.

## Testing
```bash
flutter test
```

## Play Store release
Set the real Supabase values when building:
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=GOOGLE_OAUTH_REDIRECT_URL=com.blumebyte.prosme://login-callback \
  --dart-define=PASSWORD_RECOVERY_REDIRECT_URL=com.blumebyte.prosme://login-callback \
  --dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-3851492633678585/7100000049
```

For a signed upload bundle, create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Without that file, local release builds fall back to debug signing and are not Play Store upload-ready.

GitHub repository secrets are only available inside GitHub Actions. Add these secret names for the included Android Release workflow:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_OAUTH_REDIRECT_URL`
- `PASSWORD_RECOVERY_REDIRECT_URL`

## Notes
- All images are loaded using `Image.network` and online URLs.
- The local database layer is stubbed with Drift types and ready for expansion.
