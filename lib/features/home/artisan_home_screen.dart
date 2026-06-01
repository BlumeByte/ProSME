import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/app_scaffold.dart';
import '../chat/chat_list_screen.dart';
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

  final _pages = const [
    ListingManageScreen(),
    JobsScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
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
        title: 'Artisan Dashboard',
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Listings'),
            BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
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
