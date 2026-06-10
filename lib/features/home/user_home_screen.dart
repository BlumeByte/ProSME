import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../chat/chat_list_screen.dart';
import '../listing/listing_feed_screen.dart';
import '../jobs/jobs_screen.dart';
import '../profile/profile_screen.dart';
import 'upload_request_screen.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final chatService = ref.watch(chatServiceProvider);
    final pages = [
      ListingFeedScreen(
        onOpenChatTab: () => setState(() => _currentIndex = 2),
        onOpenUploadTab: () => setState(() => _currentIndex = 1),
      ),
      const UploadRequestScreen(),
      const ChatListScreen(),
      const JobsScreen(showAppBar: false),
      const ProfileScreen(),
    ];
    final currentIndex = user == null && _currentIndex > 0 ? 0 : _currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await _confirmExit(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: AppScaffold(
        title: currentIndex == 0 ? 'ProSME   Find Professionals' : 'ProSME',
        actions: currentIndex == 0
            ? [
                IconButton(
                  onPressed: () {
                    if (user == null) {
                      context.go(RouteNames.auth);
                      return;
                    }
                    setState(() => _currentIndex = 4);
                  },
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Profile',
                ),
              ]
            : null,
        body: pages[currentIndex],
        bottomNavigationBar: StreamBuilder(
          stream: user == null ? null : chatService.watchThreads(user.id),
          builder: (context, snapshot) {
            final unread = (snapshot.data ?? const [])
                .fold<int>(0, (sum, thread) => sum + thread.unreadCount);
            return BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                if (user == null && index > 0) {
                  context.go(RouteNames.auth);
                  return;
                }
                setState(() => _currentIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                    icon: Icon(Icons.home), label: 'Home'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.upload_outlined), label: 'Upload'),
                BottomNavigationBarItem(
                  icon: _NavIconWithBadge(
                    icon: Icons.chat_bubble_outline,
                    count: unread,
                  ),
                  label: 'Chat',
                ),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'Bookings'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: 'Profile'),
              ],
            );
          },
        ),
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

Future<bool> _confirmExit(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit ProSME?'),
          content: const Text('Press Exit to close the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      ) ??
      false;
}
