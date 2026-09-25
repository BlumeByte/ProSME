import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/supabase_options.dart';
import '../firebase_options.dart';
import 'service_providers.dart';

/// Must run at the top level (not a class method) — the OS spawns a separate
/// isolate for this handler when a push arrives while the app is terminated.
@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  // FCM already shows the OS notification for messages with a `notification`
  // payload; nothing else to do while the app isn't running.
}

/// Registers this device for background/terminated push via Firebase Cloud
/// Messaging. Safe to call even when Firebase hasn't been configured yet
/// (see lib/firebase_options.dart) — it just stays inert.
class PushTokenService {
  factory PushTokenService() => _instance;
  PushTokenService._();
  static final PushTokenService _instance = PushTokenService._();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (!DefaultFirebaseOptions.isConfigured || _initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Call after sign-in: asks permission (iOS/web) and upserts the device's
  /// FCM token so the send-push-outbox function can reach this device.
  Future<void> registerForUser(String userId) async {
    if (!DefaultFirebaseOptions.isConfigured || !_initialized) return;
    if (!shouldUseSupabase()) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _upsertToken(userId, token);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
        unawaited(_upsertToken(userId, refreshed));
      });
    } catch (error, stackTrace) {
      debugPrint('Push token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _upsertToken(String userId, String token) async {
    try {
      await supabaseClient.from('device_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
    } catch (error, stackTrace) {
      debugPrint('Could not save device token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Call on sign-out so a shared/borrowed device stops receiving this
  /// member's pushes.
  Future<void> unregister() async {
    if (!DefaultFirebaseOptions.isConfigured || !_initialized) return;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || !shouldUseSupabase()) return;
      await supabaseClient.from('device_tokens').delete().eq(
            'fcm_token',
            token,
          );
    } catch (error, stackTrace) {
      debugPrint('Could not remove device token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
