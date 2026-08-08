import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings_controller.dart';
import 'service_providers.dart';

const _priorityNotificationTypes = <String>{
  'bid',
  'booking',
  'job',
  'account',
};

class NotificationService {
  factory NotificationService() => _instance;

  NotificationService._();

  static final NotificationService _instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize({bool requestPermission = false}) async {
    if (!_initialized) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _initialized = true;
    }
    if (requestPermission) await requestPermissions();
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (_permissionRequested) return true;
    _permissionRequested = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    return androidGranted && iosGranted;
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final androidDetails = AndroidNotificationDetails(
      'prosme_priority_v2',
      'ProSME Priority Updates',
      channelDescription:
          'Important ProSME alerts for bids, hiring, work updates, and account security.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 120, 250]),
      ticker: 'ProSME update',
      category: AndroidNotificationCategory.message,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }
}

final foregroundNotificationListenerProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !shouldUseSupabase()) return;

  final client = ref.watch(supabaseClientProvider);
  final notificationService = NotificationService();
  unawaited(notificationService.requestPermissions());

  final channel = client.channel('prosme_app_notifications_${user.id}');
  try {
    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'related_user_id',
        value: user.id,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        final settings = ref.read(appSettingsControllerProvider);
        final rawType = (record['type'] ?? 'system').toString();
        final type = normalizeNotificationType(rawType);

        // Phone alerts are intentionally limited to events users need to act on.
        if (!_priorityNotificationTypes.contains(type)) return;
        if (!settings.allowsPhoneNotificationType(type)) return;

        final title = (record['title'] ?? 'ProSME notification').toString();
        final body = (record['body'] ?? '').toString().trim();
        unawaited(
          notificationService.showSimpleNotification(
            title: settings.t(title),
            body: settings.t(
              body.isEmpty ? 'You have an important ProSME update.' : body,
            ),
          ),
        );
      },
    )
        .subscribe((status, [error]) {
      final statusText = status.toString().toLowerCase();
      if (statusText.contains('error') || statusText.contains('timeout')) {
        debugPrint('Notification realtime unavailable: $status $error');
      }
    });
  } catch (error, stackTrace) {
    debugPrint('Failed to start notification realtime listener: $error');
    debugPrintStack(stackTrace: stackTrace);
    return;
  }

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});
