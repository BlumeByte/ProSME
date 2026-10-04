// Firebase configuration for the `prosme-app` Firebase project, generated
// from android/app/google-services.json (Android only — no web/iOS Firebase
// app has been created yet).
//
// The corresponding server-side secrets (FIREBASE_PROJECT_ID /
// FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY) must be set on the
// `send-push-outbox` Supabase edge function from a service account key
// (Firebase console -> Project settings -> Service accounts -> Generate new
// private key) for outgoing pushes to actually send.

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

  /// True once real values (not the placeholder) are in place.
  static bool get isConfigured => (currentPlatform?.apiKey ?? '').isNotEmpty;

  static const FirebaseOptions? web = null;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDCV7lS6qEN-CNef2mCcM6itgEa7ReEURY',
    appId: '1:850287627823:android:d5856cdde71a268cc400da',
    messagingSenderId: '850287627823',
    projectId: 'prosme-app',
    storageBucket: 'prosme-app.firebasestorage.app',
  );

  static const FirebaseOptions? ios = null;
}
