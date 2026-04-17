import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

/// Initializes the Supabase client.
///
/// Call [initSupabase] once in [main] before [runApp].
/// After initialization the client is available via [Supabase.instance.client].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
}

/// Convenience getter for the global Supabase client.
SupabaseClient get supabaseClient => Supabase.instance.client;
