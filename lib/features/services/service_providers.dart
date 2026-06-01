// TODO Implement this library.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prosme/config/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple UserProfile model to represent the authenticated user.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final UserRole role;
}

/// Provider for the Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Returns true if the app should use Supabase as the backend.
/// Currently returns true if [kSupabaseUrl] is not the default placeholder.
bool shouldUseSupabase() {
  return kSupabaseUrl != 'https://wbnvifrzckjttyxhmlcf.supabase.co' || kDevMode;
}

/// Provider for the current authentication state.
/// Returns a [UserProfile] if the user is signed in, otherwise null.
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((data) {
    final session = data.session;
    if (session == null) return null;

    // Map Supabase User to our UserProfile model
    return UserProfile(
      id: session.user.id,
      email: session.user.email ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (session.user.userMetadata?['role'] ?? 'customer'),
        orElse: () => UserRole.customer,
      ),
    );
  });
});

/// Placeholder for Chat Service Provider
final chatServiceProvider = Provider<dynamic>((ref) {
  // Implementation depends on your ChatService class
  return null;
});

/// Placeholder for Listing Service Provider
final listingServiceProvider = Provider<dynamic>((ref) {
  // Implementation depends on your ListingService class
  return null;
});
