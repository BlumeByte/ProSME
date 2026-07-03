import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import '../jobs/jobs_repository.dart';

class ArtisanDashboardScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ArtisanDashboardScreen> createState() =>
      _ArtisanDashboardScreenState();
}

class _ArtisanDashboardScreenState
    extends ConsumerState<ArtisanDashboardScreen> {
  bool _seenInitialJobs = false;
  String? _latestJobId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    final jobsAsync = ref.watch(jobsStreamProvider);
    final bidsAsync = user == null
        ? const AsyncValue<List<JobBid>>.data(<JobBid>[])
        : ref.watch(artisanBidsProvider(user.id));
    final bids = bidsAsync.valueOrNull ?? const <JobBid>[];
    final bidJobIds = bids.map((bid) => bid.jobId).toSet();
    final listingsAsync = ref.watch(listingServiceProvider).watchListings();
    final status = user?.verificationStatus ?? VerificationStatus.pending;
    final isVerified = status == VerificationStatus.verified;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          settings.t('Artisan'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          user == null
              ? settings.t('Manage your services')
              : '${settings.t('Hello')}, ${user.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        StreamBuilder(
          stream: listingsAsync,
          builder: (context, snapshot) {
            final myListings = (snapshot.data ?? const [])
                .where((listing) => listing.artisanId == user?.id)
                .toList(growable: false);
            return _StatRow(
              listings: myListings.length,
              bids: bids.length,
              won: _wonBidCount(bids),
              onOpenListings: widget.onOpenListings,
              onOpenRequests: widget.onOpenJobs,
              onOpenPending: widget.onOpenChats,
              settings: settings,
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              isVerified ? Icons.verified : Icons.verified_outlined,
              color: isVerified ? Colors.green : Colors.orange,
            ),
            title: Text(settings
                .t(isVerified ? 'Verified artisan' : 'Verification needed')),
            subtitle: Text(
              settings.t(isVerified
                  ? 'Customers can see your verified badge.'
                  : 'Upload ID documents so Support can verify your profile.'),
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
                label: settings.t('My listings'),
                onTap: widget.onOpenListings,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardAction(
                icon: Icons.work_outline,
                label: settings.t('Requests'),
                onTap: widget.onOpenJobs,
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
                label: settings.t('Negotiations'),
                onTap: widget.onOpenChats,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DashboardAction(
                icon: Icons.settings_outlined,
                label: settings.t('Settings'),
                onTap: widget.onOpenSettings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                settings.t('New Job Requests'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
                onPressed: widget.onOpenJobs,
                child: Text(settings.t('View All'))),
          ],
        ),
        const SizedBox(height: 8),
        jobsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Text(
            settings.t(
              'Could not load requests. Please check your connection and try again.',
            ),
          ),
          data: (jobs) {
            final openRequests = jobs
                .where((job) =>
                    job.workStatus == 'open' &&
                    job.requestType == 'public' &&
                    job.createdBy != user?.id)
                .toList(growable: false);
            final directRequests = jobs
                .where((job) =>
                    job.requestType == 'direct' &&
                    job.targetArtisanId == user?.id &&
                    job.workStatus == 'open')
                .toList(growable: false);
            _notifyOnNewJob(openRequests);
            if (openRequests.isEmpty && directRequests.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: Text(settings.t('No customer requests yet')),
                  subtitle: Text(settings
                      .t('New jobs will appear here when users post them.')),
                ),
              );
            }
            final preview = openRequests.take(3).toList(growable: false);
            return Column(
              children: [
                if (directRequests.isNotEmpty) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_ind_outlined),
                      title: Text(settings.t('Direct booking offers')),
                      subtitle: Text(
                        settings.t(
                          '${directRequests.length} direct requests waiting for your response.',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.onOpenJobs,
                    ),
                  ),
                  ...directRequests.take(3).map(
                        (job) => Card(
                          child: ListTile(
                            title: Text(job.title),
                            subtitle: Text(
                              '${job.location} - ${settings.t('Offer')}: ${formatMoney(job.budget, currencyCode)}',
                            ),
                            trailing: FilledButton(
                              onPressed: () => context
                                  .push('${RouteNames.jobDetail}/${job.id}'),
                              child: Text(settings.t('Respond')),
                            ),
                            onTap: () => context
                                .push('${RouteNames.jobDetail}/${job.id}'),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                ],
                ...preview.map(
                  (job) {
                    final hasBid = bidJobIds.contains(job.id);
                    final shownAmount = job.acceptedAmount ?? job.budget;
                    final amountLabel = job.acceptedAmount == null
                        ? settings.t('Budget')
                        : settings.t('Accepted amount');
                    return Card(
                      child: ListTile(
                        title: Text(job.title),
                        subtitle: Text(
                          '${job.location} - $amountLabel: ${formatMoney(shownAmount, currencyCode)}',
                        ),
                        trailing: FilledButton(
                          onPressed: () =>
                              context.push('${RouteNames.jobDetail}/${job.id}'),
                          child: Text(settings.t(hasBid ? 'Edit bid' : 'Bid')),
                        ),
                        onTap: () =>
                            context.push('${RouteNames.jobDetail}/${job.id}'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _notifyOnNewJob(List<JobFeedItem> jobs) {
    if (jobs.isEmpty) return;
    final latest = jobs.first;
    if (!_seenInitialJobs) {
      _seenInitialJobs = true;
      _latestJobId = latest.id;
      return;
    }
    if (_latestJobId == latest.id) return;
    _latestJobId = latest.id;
    final settings = ref.read(appSettingsControllerProvider);
    if (!settings.phoneNotifications) return;
    NotificationService().showSimpleNotification(
      title: 'New job request',
      body: latest.title,
    );
  }
}

int _wonBidCount(List<JobBid> bids) {
  return bids.where((bid) => bid.status == 'accepted').length;
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.listings,
    required this.bids,
    required this.won,
    required this.onOpenListings,
    required this.onOpenRequests,
    required this.onOpenPending,
    required this.settings,
  });

  final int listings;
  final int bids;
  final int won;
  final VoidCallback onOpenListings;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenPending;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: listings.toString(),
            label: settings.t('Services'),
            icon: Icons.storefront_outlined,
            onTap: onOpenListings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: bids.toString(),
            label: settings.t('Bids'),
            icon: Icons.request_quote_outlined,
            onTap: onOpenRequests,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: won.toString(),
            label: settings.t('Won'),
            icon: Icons.emoji_events_outlined,
            onTap: onOpenPending,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
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
