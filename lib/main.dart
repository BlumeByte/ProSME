import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/supabase_options.dart';
import 'services/app_launch_service.dart';
import 'services/chat_sync_service.dart';
import 'services/db_service.dart';
import 'services/service_providers.dart';
import 'services/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (_) {}
  await LocalDbService.instance.init();
  await AppLaunchService.init();
  await ThemeModeController.init();
  if (shouldUseSupabase()) {
    await ChatSyncService.syncPending(
      supabase: supabaseClient,
      localDb: LocalDbService.instance,
    );
  }
  runApp(const ProviderScope(child: ProSMEApp()));
}
