import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/artisan_verification_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/chat/chat_thread_screen.dart';
import '../features/home/artisan_home_screen.dart';
import '../features/home/user_home_screen.dart';
import '../features/invoice/invoice_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/listing/listing_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/support/ai_support_screen.dart';
import '../models/app_user.dart';
import '../routes/route_names.dart';
import '../services/app_launch_service.dart';
import '../services/service_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStream = ref.watch(authStateProvider.stream);
  final refreshListenable = StreamRouterRefresh(authStream);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.onboarding,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider).valueOrNull;
      final isLoggedIn = authState != null;
      final fullPath = state.fullPath ?? state.matchedLocation;
      final isOnboarding = fullPath == RouteNames.onboarding;

      if (!isLoggedIn &&
          !AppLaunchService.hasSeenWelcome &&
          !isOnboarding) {
        return RouteNames.onboarding;
      }

      if (!isLoggedIn &&
          AppLaunchService.hasSeenWelcome &&
          isOnboarding) {
        return RouteNames.home;
      }

      if (!isLoggedIn && _requiresAuth(fullPath)) {
        return RouteNames.auth;
      }

      if (isLoggedIn && isOnboarding) {
        return _homeForRole(authState);
      }

      if (isLoggedIn && fullPath == RouteNames.auth) {
        return _homeForRole(authState);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: RouteNames.role,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.artisanVerification,
        builder: (context, state) => const ArtisanVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const UserHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.artisanHome,
        builder: (context, state) => const ArtisanHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.adminHome,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '${RouteNames.listingDetail}/:id',
        builder: (context, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${RouteNames.chatThread}/:id',
        builder: (context, state) =>
            ChatThreadScreen(threadId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.invoice,
        builder: (context, state) => const InvoiceScreen(),
      ),
      GoRoute(
        path: '${RouteNames.jobDetail}/:id',
        builder: (context, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.aiSupport,
        builder: (context, state) => const AiSupportScreen(),
      ),
      GoRoute(
        path: RouteNames.saved,
        builder: (context, state) => const SavedScreen(),
      ),
    ],
  );
});

bool _requiresAuth(String fullPath) {
  final protectedExactPaths = <String>{
    RouteNames.role,
    RouteNames.artisanVerification,
    RouteNames.artisanHome,
    RouteNames.adminHome,
    RouteNames.invoice,
    RouteNames.aiSupport,
    RouteNames.saved,
  };
  if (protectedExactPaths.contains(fullPath)) return true;
  if (fullPath.startsWith('${RouteNames.listingDetail}/')) return true;
  if (fullPath.startsWith('${RouteNames.chatThread}/')) return true;
  if (fullPath.startsWith('${RouteNames.jobDetail}/')) return true;
  return false;
}

String _homeForRole(AppUser? user) {
  switch (user?.role) {
    case UserRole.artisan:
      return RouteNames.artisanHome;
    case UserRole.admin:
      return RouteNames.adminHome;
    case UserRole.customer:
    default:
      return RouteNames.home;
  }
}

class StreamRouterRefresh extends ChangeNotifier {
  StreamRouterRefresh(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
