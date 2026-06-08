import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../models/artisan_profile.dart';
import '../../services/service_providers.dart';
import 'developer_dashboard_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user?.role == UserRole.developer) {
      return const DeveloperDashboardScreen();
    }

    final sections = [
      const _VerificationQueue(),
      const _AdminInfoPanel(
        title: 'Job Moderation',
        body:
            'Review posted jobs from the Bookings tab and remove anything that violates ProSME rules.',
        icon: Icons.work_outline,
      ),
      const _AdminInfoPanel(
        title: 'Reports',
        body:
            'Verification decisions and email tasks are recorded in Supabase for audit review.',
        icon: Icons.analytics_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Dashboard')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.verified_user_outlined),
                label: Text('Verify'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.work_outline),
                label: Text('Jobs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                label: Text('Reports'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: sections[_selectedIndex]),
        ],
      ),
    );
  }
}

class _VerificationQueue extends ConsumerWidget {
  const _VerificationQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminService = ref.watch(adminServiceProvider);
    return StreamBuilder<List<ArtisanProfile>>(
      stream: adminService.watchVerificationQueue(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load verification queue. Check Supabase policies.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final queue = snapshot.data!;
        if (queue.isEmpty) {
          return const _AdminInfoPanel(
            title: 'No pending verifications',
            body: 'New artisan ID submissions will appear here automatically.',
            icon: Icons.verified_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: queue.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final profile = queue[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Artisan ${profile.userId}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(profile.verifiedStatus.name)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('ID: ${profile.nationalIdUrl}'),
                    if (profile.location.isNotEmpty)
                      Text('Location: ${profile.location}'),
                    if (profile.categories.isNotEmpty)
                      Text('Categories: ${profile.categories.join(', ')}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _review(
                              context,
                              ref,
                              profile.userId,
                              approved: false,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _review(
                              context,
                              ref,
                              profile.userId,
                              approved: true,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String userId, {
    required bool approved,
  }) async {
    try {
      await ref.read(adminServiceProvider).reviewArtisan(
            userId: userId,
            approved: approved,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Artisan verified.' : 'Artisan rejected.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update verification.')),
        );
      }
    }
  }
}

class _AdminInfoPanel extends StatelessWidget {
  const _AdminInfoPanel({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
