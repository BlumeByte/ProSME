import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../services/service_providers.dart';
import '../jobs/jobs_repository.dart';

class ArtisanDashboardScreen extends ConsumerWidget {
  const ArtisanDashboardScreen({
    super.key,
    required this.onOpenListings,
    required this.onOpenJobs,
    required this.onOpenChats,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenListings;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final jobsAsync = ref.watch(jobsStreamProvider);
    final status = user?.verificationStatus ?? VerificationStatus.pending;
    final isVerified = status == VerificationStatus.verified;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Artisan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          user == null ? 'Manage your services' : 'Hello, ${user.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              isVerified ? Icons.verified : Icons.verified_outlined,
              color: isVerified ? Colors.green : Colors.orange,
            ),
            title:
                Text(isVerified ? 'Verified artisan' : 'Verification needed'),
            subtitle: Text(
              isVerified
                  ? 'Customers can see your verified badge.'
                  : 'Upload ID documents so admin can verify your profile.',
            ),
            trailing: isVerified ? null : const Icon(Icons.info_outline),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardAction(
                icon: Icons.storefront,
                label: 'My listings',
                onTap: onOpenListings,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardAction(
                icon: Icons.work_outline,
                label: 'Requests',
                onTap: onOpenJobs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DashboardAction(
                icon: Icons.chat_bubble_outline,
                label: 'Negotiations',
                onTap: onOpenChats,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardAction(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: onOpenSettings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Open requests', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        jobsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Text('Could not load requests: $error'),
          data: (jobs) {
            if (jobs.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('No customer requests yet'),
                  subtitle:
                      Text('New jobs will appear here when users post them.'),
                ),
              );
            }
            final preview = jobs.take(3).toList(growable: false);
            return Column(
              children: [
                ...preview.map(
                  (job) => Card(
                    child: ListTile(
                      title: Text(job.title),
                      subtitle: Text(
                        '${job.location} - $kCurrencySymbol ${job.budget.toStringAsFixed(2)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onOpenJobs,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenJobs,
                    child: const Text('View all'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
