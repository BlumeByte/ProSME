import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../chat/chat_list_screen.dart';
import '../jobs/jobs_repository.dart';
import 'artisan_dashboard_screen.dart';
import '../jobs/jobs_screen.dart';
import '../listing/listing_manage_screen.dart';
import '../profile/profile_screen.dart';

class ArtisanHomeScreen extends ConsumerStatefulWidget {
  const ArtisanHomeScreen({super.key});

  @override
  ConsumerState<ArtisanHomeScreen> createState() => _ArtisanHomeScreenState();
}

class _ArtisanHomeScreenState extends ConsumerState<ArtisanHomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ArtisanDashboardScreen(
        onOpenListings: () => setState(() => _currentIndex = 1),
        onOpenJobs: () => setState(() => _currentIndex = 2),
        onOpenChats: () => setState(() => _currentIndex = 3),
        onOpenSettings: () => setState(() => _currentIndex = 4),
      ),
      const ListingManageScreen(),
      const JobsScreen(showAppBar: false),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final chatService = ref.watch(chatServiceProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final currentIndex = user == null && _currentIndex > 0 ? 0 : _currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        await _confirmExitApp();
      },
      child: StreamBuilder(
        stream: user == null ? null : chatService.watchThreads(user.id),
        builder: (context, snapshot) {
          final unread = (snapshot.data ?? const [])
              .fold<int>(0, (sum, thread) => sum + thread.unreadCount);
          final navigationItems = [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: settings.t('Artisan'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.store_outlined),
              activeIcon: const Icon(Icons.store),
              label: settings.t('Listings'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.work_outline),
              activeIcon: const Icon(Icons.work),
              label: settings.t('Jobs'),
            ),
            BottomNavigationBarItem(
              icon: _NavIconWithBadge(
                icon: Icons.chat_bubble_outline,
                count: unread,
              ),
              activeIcon: _NavIconWithBadge(
                icon: Icons.chat_bubble,
                count: unread,
              ),
              label: settings.t('Chats'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: settings.t('Settings'),
            ),
          ];
          void selectDestination(int index) {
            if (user == null && index > 0) {
              context.go(RouteNames.auth);
              return;
            }
            setState(() => _currentIndex = index);
          }

          return AppScaffold(
            title: settings.t('Artisan Dashboard'),
            actions: [
              IconButton(
                onPressed: () async {
                  await ref.read(listingServiceProvider).fetchListings();
                  ref.invalidate(listingsStreamProvider);
                  ref.invalidate(jobsStreamProvider);
                },
                icon: const Icon(Icons.refresh),
                tooltip: settings.t('Refresh'),
              ),
              IconButton(
                onPressed: () => setState(() => _currentIndex = 2),
                icon: const Icon(Icons.search),
                tooltip: settings.t('Search requests'),
              ),
            ],
            selectedIndex: currentIndex,
            onDestinationSelected: selectDestination,
            desktopDestinations: navigationItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: item.icon,
                    selectedIcon: item.activeIcon,
                    label: Text(item.label ?? ''),
                  ),
                )
                .toList(growable: false),
            body: IndexedStack(index: currentIndex, children: _pages),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: selectDestination,
              type: BottomNavigationBarType.fixed,
              items: navigationItems,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmExitApp() async {
    final settings = ref.read(appSettingsControllerProvider);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Exit ProSME?')),
        content: Text(settings.t('Do you want to close the app?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.t('Exit')),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }
}

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge.count(count: count, child: Icon(icon));
  }
}
