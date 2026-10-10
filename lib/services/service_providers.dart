import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../config/supabase_options.dart';
import '../features/home/account_completion.dart';
import '../models/listing.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'realtime_chat_service.dart';
import 'listing_service.dart';
import 'realtime_listing_service.dart';
import 'payment_service.dart';
import 'admin_service.dart';
import 'db_service.dart';
import 'saved_service.dart';

/// Exposes the single global [SupabaseClient] used by Android, iOS and web.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabaseClient;
});

bool isSupabaseInitialized() {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

bool hasSupabaseCredentials() {
  return kSupabaseUrl.trim().isNotEmpty &&
      kSupabaseAnonKey.trim().isNotEmpty &&
      kSupabaseAnonKey != kSupabaseAnonKeyPlaceholder;
}

bool shouldUseSupabase() => isSupabaseInitialized() && hasSupabaseCredentials();

/// A single long-lived authentication service is shared by every consumer.
/// This prevents multiple auth subscriptions from independently resolving the
/// same profile during startup/token refresh and reduces unnecessary requests.
final authServiceProvider = Provider<AuthService>((ref) {
  if (!shouldUseSupabase()) {
    return MockAuthService();
  }
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

final supabaseAuthServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

/// Riverpod shares this stream across the router and UI. Returning users get
/// the restored Supabase session rather than a new in-memory auth state.
final authStateProvider = StreamProvider((ref) {
  // Every profile update matters to a consumer (including phone, description,
  // country and the sign-in security gate). A partial-field comparator
  // silently discarded successful saves and security-state transitions.
  return ref.watch(authServiceProvider).authStateChanges();
});

final passwordRecoveryActiveProvider = StateProvider<bool>((ref) => false);

/// Set by a notification tap (or anything else outside the home shell) to
/// jump the bottom navigation to a specific tab — e.g. Profile, to finish an
/// account item. Read-and-cleared by the home screen that owns the tab bar,
/// since the tab index is otherwise private `State` the rest of the app
/// cannot reach.
final requestedHomeTabProvider = StateProvider<int?>((ref) => null);

/// Set alongside [requestedHomeTabProvider] when the Profile tab should also
/// open a specific flow (verify email, add a photo, ...) once it is showing.
/// Read-and-cleared by [ProfileScreen].
final requestedProfileActionProvider =
    StateProvider<AccountCompletionAction?>((ref) => null);

final listingServiceProvider = Provider<ListingService>((ref) {
  if (!shouldUseSupabase()) {
    return MockListingService();
  }
  final service = RealtimeListingService(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final listingsStreamProvider = StreamProvider<List<Listing>>((ref) {
  return ref.watch(listingServiceProvider).watchListings();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  if (!shouldUseSupabase()) {
    return MockChatService();
  }
  final service = RealtimeChatService(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final paymentServiceProvider = Provider((ref) {
  if (shouldUseSupabase()) {
    return PaymentService(ref.watch(supabaseClientProvider));
  }
  return const PaymentService();
});

final verificationSubscriptionProvider =
    StreamProvider.family((ref, String userId) {
  return ref
      .watch(paymentServiceProvider)
      .watchVerificationSubscription(userId);
});

final adminServiceProvider = Provider((ref) {
  if (shouldUseSupabase()) {
    return AdminService(ref.watch(supabaseClientProvider));
  }
  return const AdminService();
});

final localDbProvider = Provider((ref) => LocalDbService.instance);

final savedServiceProvider = Provider<SavedService>((ref) {
  if (!shouldUseSupabase()) {
    return MockSavedService();
  }
  return SupabaseSavedService(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbProvider),
  );
});

/// Emits the list of listing IDs saved by the given user, updating in real-time.
final savedListingIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  return ref.watch(savedServiceProvider).watchSavedListingIds(userId);
});
