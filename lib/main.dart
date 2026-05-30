import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/supabase_options.dart';
import 'services/app_launch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (_) {}
  await AppLaunchService.init();
  runApp(const ProviderScope(child: ProSMEApp()));
}
