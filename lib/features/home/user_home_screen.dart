import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../chat/chat_list_screen.dart';
import '../listing/listing_feed_screen.dart';
import '../marketplace/jobs/presentation/jobs_screen.dart';
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
    final pages = [
      ListingFeedScreen(onOpenChatTab: () => setState(() => _currentIndex = 2)),
      const UploadRequestScreen(),
      const ChatListScreen(),
      const JobsScreen(),
      const ProfileScreen(),
    ];
    final currentIndex = user == null && _currentIndex > 0 ? 0 : _currentIndex;

    return WillPopScope(
      onWillPop: () async {
        if (currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        final shouldExit = await _confirmExit(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
        return false;
      },
      child: AppScaffold(
        title: currentIndex == 0 ? 'ProSME   Find Professionals' : 'Pro SME',
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (user == null && index > 0) {
              context.go(RouteNames.auth);
              return;
            }
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.upload_outlined), label: 'Upload'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmExit(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit Pro SME?'),
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
