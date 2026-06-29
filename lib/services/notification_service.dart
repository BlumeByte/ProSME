import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings_controller.dart';
import 'service_providers.dart';

class NotificationService {
  factory NotificationService() => _instance;

  NotificationService._();

  static final NotificationService _instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({bool requestPermission = false}) async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
    if (requestPermission) await requestPermissions();
  }

  Future<bool> requestPermissions() async {
    await initialize();
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
      'prosme_channel',
      'Pro SME Notifications',
      channelDescription:
          'Alerts for ProSME chats, jobs, bids, and account updates.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 120, 250]),
      ticker: 'ProSME alert',
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
  final channel = client
      .channel('prosme_app_notifications_${user.id}')
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
          final type = (record['type'] ?? 'system').toString();
          if (!settings.allowsPhoneNotificationType(type)) return;
          final title = (record['title'] ?? 'ProSME notification').toString();
          final body = (record['body'] ?? '').toString().trim();
          notificationService.showSimpleNotification(
            title: settings.t(title),
            body: settings
                .t(body.isEmpty ? 'You have a new ProSME update.' : body),
          );
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
