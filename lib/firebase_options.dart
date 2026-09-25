// Placeholder Firebase configuration.
//
// Push notifications stay silently disabled until this file is replaced with
// real values. To enable them:
//   1. Create a Firebase project (or reuse an existing one) at
//      https://console.firebase.google.com
//   2. Run `flutterfire configure` from the repo root and select that project.
//      This OVERWRITES this file with your project's real options and adds
//      android/app/google-services.json + ios/Runner/GoogleService-Info.plist.
//   3. In Supabase, deploy the `send-push-outbox` edge function and set the
//      FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY
//      secrets from a service account key (Firebase console -> Project
//      settings -> Service accounts -> Generate new private key).
//
// See README.md "Push notifications (Firebase)" for the full walkthrough.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  /// True once `flutterfire configure` has filled in real values.
  static bool get isConfigured => (currentPlatform?.apiKey ?? '').isNotEmpty;

  static const FirebaseOptions? web = null;

  static const FirebaseOptions? android = null;

  static const FirebaseOptions? ios = null;
}
