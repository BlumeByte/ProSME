import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../listing/listing_feed_screen.dart';
import '../saved/saved_screen.dart';
import '../jobs/jobs_screen.dart';
import '../profile/profile_screen.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    ListingFeedScreen(),
    SavedScreen(),
    JobsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final currentIndex = user == null && _currentIndex > 0 ? 0 : _currentIndex;

    return AppScaffold(
      title: 'ProSME',
      body: _pages[currentIndex],
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
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
