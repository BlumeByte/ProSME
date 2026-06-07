import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/app_scaffold.dart';
import '../chat/chat_list_screen.dart';
import 'artisan_dashboard_screen.dart';
import '../jobs/jobs_screen.dart';
import '../listing/listing_manage_screen.dart';
import '../profile/profile_screen.dart';

class ArtisanHomeScreen extends StatefulWidget {
  const ArtisanHomeScreen({super.key});

  @override
  State<ArtisanHomeScreen> createState() => _ArtisanHomeScreenState();
}

class _ArtisanHomeScreenState extends State<ArtisanHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await _confirmExit(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: AppScaffold(
        title: 'Artisan Dashboard',
        actions: [
          IconButton(
            onPressed: () => setState(() => _currentIndex = 2),
            icon: const Icon(Icons.search),
            tooltip: 'Search requests',
          ),
        ],
        body: pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Artisan'),
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Listings'),
            BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
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
