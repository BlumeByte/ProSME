import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

/// Initializes the single Supabase client shared by Android, iOS and web.
///
/// `supabase_flutter` persists the authenticated session using its platform
/// local storage implementation. Keeping auto refresh and PKCE enabled gives
/// every client the same durable login/session behavior and lets web/mobile
/// share one backend identity.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: kSupabaseUrl,
    publishableKey: kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );
}

/// Convenience getter for the global Supabase client.
SupabaseClient get supabaseClient => Supabase.instance.client;
