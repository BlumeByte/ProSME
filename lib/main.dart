import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/supabase_options.dart';
import 'services/app_launch_service.dart';
import 'services/app_settings_controller.dart';
import 'services/chat_sync_service.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';
import 'services/service_providers.dart';
import 'services/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  ErrorWidget.builder = (details) => const Material(
        color: Color(0xFFF8FAFC),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Processing, please wait. If this takes too long, restart ProSME.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
  try {
    await initSupabase();
  } catch (_) {}
  await LocalDbService.instance.init();
  await AppLaunchService.init();
  await ThemeModeController.init();
  await AppSettingsController.init();
  unawaited(NotificationService().initialize());
  if (shouldUseSupabase()) {
    unawaited(
      ChatSyncService.syncPending(
        supabase: supabaseClient,
        localDb: LocalDbService.instance,
      ),
    );
  }
  runApp(const ProviderScope(child: ProSMEApp()));
}
