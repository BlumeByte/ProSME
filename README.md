# ProSME

ProSME is a lightweight Flutter marketplace for connecting customers with verified SMEs and artisans. It supports quick registration, chat, invoices, payments, job tracking, and an admin dashboard designed for low-literacy users.

## Features
- **Three roles**: Customer, Artisan, Admin
- **Simple onboarding** with role selection and artisan verification flow
- **Listing feed** with search and category chips
- **Listing details** with image carousel, map preview, and quick actions
- **Realtime chat** (mock + Firestore ready)
- **Invoice workflow** with Paystack MoMo or cash option
- **Job tracking** with timelines and ETA updates
- **AI support** FAQ screen

## Tech Stack
- Flutter (stable)
- State management: Riverpod
- Routing: go_router
- Local DB (offline-first): Drift (stubbed service ready)
- Cloud sync/auth: Firebase Auth + Firestore
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

### 2) Firebase setup (for production mode)
1. Create a Firebase project.
2. Add Android, iOS, and Web apps in Firebase Console.
3. Download configuration files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `web/firebase-messaging-sw.js` (if using web messaging)
4. Enable Authentication providers (Email, Phone, Google).
5. Create Firestore collections: `users`, `listings`, `threads`, `messages`, `invoices`, `jobs`.

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
`lib/config/constants.dart` contains `kDevMode`. When `true`, the app uses mock services and demo data. Set to `false` to enable Firebase services.

## Testing
```bash
flutter test
```

## Notes
- All images are loaded using `Image.network` and online URLs.
- The local database layer is stubbed with Drift types and ready for expansion.
