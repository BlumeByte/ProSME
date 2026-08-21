import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/admob_banner.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/sme_page_banner.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import '../chat/chat_list_screen.dart';
import '../listing/listing_feed_screen.dart';
import '../jobs/jobs_screen.dart';
import '../profile/profile_screen.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  int _currentIndex = 0;
  int _bannerIndex = 0;
  final int _bannerSeed = DateTime.now().microsecondsSinceEpoch;
  int _lastUnreadChats = 0;
  bool _seenInitialUnreadChats = false;
  bool _showOpeningBanner = true;
  late final PageController _bannerController;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_shouldShowBanner) return;
      final banners = _buildBanners(ref.read(appSettingsControllerProvider));
      if (banners.length < 2 || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final chatService = ref.watch(chatServiceProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final currentIndex = user == null && _currentIndex > 0 ? 0 : _currentIndex;
    final banners = _buildBanners(settings);
    final pages = [
      ListingFeedScreen(
        openingBanner: _shouldShowBanner
            ? _BannerSlider(
                controller: _bannerController,
                banners: banners,
                currentIndex: _bannerIndex,
                onPageChanged: (index) => setState(() => _bannerIndex = index),
              )
            : null,
        onOpenUploadTab: () => _openTab(2),
        onLeaveHomeContent: _hideOpeningBanner,
      ),
      const ChatListScreen(),
      const JobsScreen(showAppBar: false),
      const ProfileScreen(),
    ];

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
          _notifyOnUnreadChat(unread, settings);
          final navigationItems = [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: settings.t('Home'),
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
              label: settings.t('Chat'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: settings.t('Bookings'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: settings.t('Profile'),
            ),
          ];
          void selectDestination(int index) {
            if (user == null && index > 0) {
              context.go(RouteNames.auth);
              return;
            }
            _openTab(index);
          }

          return AppScaffold(
            title: currentIndex == 0
                ? settings.t('ProSME   Find Professionals')
                : settings.t('ProSME'),
            actions: [
              IconButton(
                onPressed: () async {
                  await ref.read(listingServiceProvider).fetchListings();
                  ref.invalidate(listingsStreamProvider);
                },
                icon: const Icon(Icons.refresh),
                tooltip: settings.t('Refresh'),
              ),
              IconButton(
                onPressed: () {
                  if (user == null) {
                    context.go(RouteNames.auth);
                    return;
                  }
                  _openTab(3);
                },
                icon: const Icon(Icons.person_outline),
                tooltip: settings.t('Profile'),
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
            body: Column(
              children: [
                Expanded(
                  child: IndexedStack(index: currentIndex, children: pages),
                ),
                if (currentIndex == 0) const AdMobBannerSlot(),
              ],
            ),
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

  bool get _shouldShowBanner => _showOpeningBanner && _currentIndex == 0;

  void _openTab(int index) {
    setState(() {
      if (index != 0) _showOpeningBanner = false;
      _currentIndex = index;
    });
  }

  void _hideOpeningBanner() {
    if (!_showOpeningBanner) return;
    setState(() => _showOpeningBanner = false);
  }

  List<({String title, String body, String image})> _buildBanners(
    AppSettings settings,
  ) {
    final banners = [
      (
        title: settings.t('Find trusted SME services'),
        body: settings.t(
          'Discover artisans, compare service listings, and keep local work easy to follow.',
        ),
        image: SmePageBanner.marketImage,
      ),
      (
        title: settings.t('Post clear work requests'),
        body: settings.t(
          'SMEs respond faster when your location, budget, photos, and service needs are organized.',
        ),
        image: SmePageBanner.workshopImage,
      ),
      (
        title: settings.t('Keep service conversations together'),
        body: settings.t(
          'Use chat and alerts to keep requests, bids, and next steps connected to the job.',
        ),
        image: SmePageBanner.craftImage,
      ),
      (
        title: settings.t('Track bookings and bids'),
        body: settings.t(
          'Customers and artisans can follow accepted work, invoice records, and job history.',
        ),
        image: SmePageBanner.recordsImage,
      ),
      (
        title: settings.t('Grow with ProSME promotions'),
        body: settings.t(
          'Verified profiles, fresh offers, and seasonal service prompts help serious artisans stand out.',
        ),
        image: SmePageBanner.promoImage,
      ),
      (
        title: settings.t('Small businesses move communities'),
        body: settings.t(
          'Every booking supports local skills, steady income, and better services close to home.',
        ),
        image: SmePageBanner.cafeImage,
      ),
      (
        title: settings.t('Turn skills into repeat work'),
        body: settings.t(
          'Clear profiles, fair pricing, and timely updates help SMEs earn trust one job at a time.',
        ),
        image: SmePageBanner.makerImage,
      ),
      (
        title: settings.t('Hire local, work smarter'),
        body: settings.t(
          'Find nearby professionals, compare updates, and keep service decisions organized.',
        ),
        image: SmePageBanner.serviceImage,
      ),
    ];
    final shuffled = [...banners]..shuffle(math.Random(_bannerSeed));
    return shuffled;
  }

  void _notifyOnUnreadChat(int unread, AppSettings settings) {
    if (!_seenInitialUnreadChats) {
      _seenInitialUnreadChats = true;
      _lastUnreadChats = unread;
      return;
    }
    if (unread <= _lastUnreadChats) {
      _lastUnreadChats = unread;
      return;
    }
    _lastUnreadChats = unread;
    if (!settings.phoneNotifications) return;
    NotificationService().showSimpleNotification(
      title: settings.t('New chat message'),
      body: settings.t('Open ProSME to read and reply.'),
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

class _BannerSlider extends StatelessWidget {
  const _BannerSlider({
    required this.controller,
    required this.banners,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<({String title, String body, String image})> banners;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final height = screenWidth < 420 ? 196.0 : 234.0;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return SmePageBanner(
                title: banner.title,
                body: banner.body,
                imageUrl: banner.image,
              );
            },
          ),
          Positioned(
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == currentIndex ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(
                      alpha: index == currentIndex ? 0.92 : 0.48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
