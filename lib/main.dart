import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (_) {}
  runApp(const ProviderScope(child: ProSMEApp()));
}
