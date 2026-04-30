import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../config/supabase_options.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'listing_service.dart';
import 'payment_service.dart';
import 'admin_service.dart';
import 'db_service.dart';

/// Exposes the global [SupabaseClient] as a Riverpod provider.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabaseClient;
});

final authServiceProvider = Provider<AuthService>((ref) {
  if (kDevMode) {
    return MockAuthService();
  }
  return SupabaseAuthService(Supabase.instance.client);
});

/// A Supabase-backed [AuthService] provider.
/// Switch [authServiceProvider] to use this when you want Supabase Auth.
final supabaseAuthServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final listingServiceProvider = Provider<ListingService>((ref) {
  if (kDevMode) {
    return MockListingService();
  }
  return SupabaseListingService(Supabase.instance.client);
});

final chatServiceProvider = Provider<ChatService>((ref) {
  if (kDevMode) {
    return MockChatService();
  }
  return SupabaseChatService(Supabase.instance.client);
});

final paymentServiceProvider = Provider((ref) => PaymentService());

final adminServiceProvider = Provider((ref) => AdminService());

final localDbProvider = Provider((ref) => LocalDbService());
