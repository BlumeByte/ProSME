import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
import 'config/app_colors.dart';
import 'config/supabase_options.dart';
import 'routes/route_names.dart';
import 'services/app_launch_service.dart';
import 'services/app_settings_controller.dart';
import 'services/analytics_service.dart';
import 'services/chat_sync_service.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';
import 'services/service_providers.dart';
import 'services/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  ErrorWidget.builder = (details) => const _AppErrorFallback();

  // Supabase owns the authenticated session for every platform. Do not fall
  // back to an in-memory mock when initialization has a transient problem;
  // doing so makes users appear signed out and causes data created in that
  // session to disappear after restart.
  await initSupabase();

  // Load the lightweight local state needed for the first frame. Supabase
  // session restoration is already complete at this point, so returning users
  // can be routed directly to their authenticated home screen.
  await LocalDbService.instance.init();
  await AppLaunchService.init();
  await ThemeModeController.init();
  await AppSettingsController.init();

  runApp(const ProviderScope(child: ProSMEApp()));

  // Non-critical startup work must never delay the first usable frame.
  if (!kIsWeb) {
    unawaited(MobileAds.instance.initialize());
  }
  unawaited(NotificationService().initialize());
  unawaited(AnalyticsService.trackAppOpen());
  if (shouldUseSupabase()) {
    unawaited(
      ChatSyncService.syncPending(
        supabase: supabaseClient,
        localDb: LocalDbService.instance,
      ),
    );
  }
}

class _AppErrorFallback extends StatelessWidget {
  const _AppErrorFallback();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    return Material(
      color: colors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Processing, please wait. If this takes too long, restart ProSME.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go(RouteNames.home),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
