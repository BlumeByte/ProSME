# ProSME

ProSME is a lightweight Flutter marketplace for connecting customers with verified SMEs and artisans. It supports quick registration, chat, invoices, payments, job tracking, and an admin dashboard designed for low-literacy users.

## Features
- **Three roles**: Customer, Artisan, Admin
- **Simple onboarding** with role selection and artisan verification flow
- **Listing feed** with search and category chips
- **Listing details** with image carousel, map preview, and quick actions
- **Realtime chat** (mock + Supabase Realtime ready)
- **Invoice workflow** with Paystack MoMo or cash option
- **Job tracking** with timelines and ETA updates
- **AI support** FAQ screen

## Tech Stack
- Flutter (stable)
- State management: Riverpod
- Routing: go_router
- Local DB (offline-first): Drift (stubbed service ready)
- Cloud sync/auth: Supabase Auth + Postgres + Realtime
- Notifications: flutter_local_notifications
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
2. Enable Authentication providers you need (Email, Google, Phone/OTP if implemented).
3. Apply migration SQL:
   - Run every file in `supabase/migrations/` in timestamp order.
4. For Google OAuth on Android, add this redirect URL in Supabase Auth settings:
   - `<your.android.applicationId>://login-callback`
5. Add runtime defines when running the app:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
     --dart-define=GOOGLE_OAUTH_REDIRECT_URL=<your.android.applicationId>://login-callback
   ```
6. Verify realtime feed:
   - Open one signed-in client and keep listings/chat/jobs screens open.
   - Insert/update rows in `listings`, `messages`, or `jobs`.
   - Confirm the app stream updates without restart.

### 3) Enable Google Maps
1. Get a Google Maps API key.
2. Android: set in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
     android:name="com.google.android.geo.API_KEY"
     android:value="YOUR_API_KEY" />
   ```
3. iOS: set in `ios/Runner/AppDelegate.swift` and `Info.plist`.
4. Web: configure in `web/index.html`.

### 4) Paystack setup
- Use Paystack’s hosted checkout URL for MoMo.
- Update the Paystack public key in your payment service if needed.

### 5) Run the app
```bash
flutter run
```

## Dev Mode
`kDevMode` is controlled with `--dart-define=DEV_MODE=true`. Without it, the app attempts Supabase initialization and falls back to mocks if Supabase is unavailable.

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
  --dart-define=GOOGLE_OAUTH_REDIRECT_URL=com.prosme.app://login-callback
```

For a signed upload bundle, create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Without that file, local release builds fall back to debug signing and are not Play Store upload-ready.

## Notes
- All images are loaded using `Image.network` and online URLs.
- The local database layer is stubbed with Drift types and ready for expansion.
