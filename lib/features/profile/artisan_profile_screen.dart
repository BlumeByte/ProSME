import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/currency.dart';
import '../../core/utils/service_categories.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/listing.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../jobs/jobs_repository.dart';

class ArtisanProfileScreen extends ConsumerWidget {
  const ArtisanProfileScreen({super.key, required this.artisanId});

  final String artisanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsFuture = ref.watch(listingServiceProvider).fetchListings();
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    final bids = ref.watch(artisanBidsProvider(artisanId)).valueOrNull ??
        const <JobBid>[];
    final ratings = ref.watch(artisanRatingsProvider(artisanId)).valueOrNull ??
        const <JobRating>[];

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Professional profile')),
      ),
      body: FutureBuilder<List<Listing>>(
        future: listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(settings.t('Could not load professional profile.')),
              ),
            );
          }
          if (!snapshot.hasData) {
            return LoadingState(label: settings.t('Loading profile...'));
          }

          final listings = snapshot.data!
              .where((listing) => listing.artisanId == artisanId)
              .toList(growable: false);
          final first = listings.isEmpty ? null : listings.first;
          final name = first?.artisanName?.trim().isNotEmpty == true
              ? first!.artisanName!.trim()
              : settings.t('Professional');
          final avatarUrl = first?.artisanPhotoUrl;
          final isVerified = listings.any((listing) => listing.verifiedOnly);
          final isBusy = listings.any((listing) => listing.artisanBusy);
          final wonBids = bids.where((bid) => bid.status == 'accepted').length;
          final categories = listings
              .map((listing) => normalizeServiceCategory(listing.category))
              .where((category) => category.trim().isNotEmpty)
              .toSet()
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage: avatarUrl?.trim().isNotEmpty == true
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: avatarUrl?.trim().isNotEmpty == true
                            ? null
                            : Text(
                                name.isEmpty ? 'P' : name[0].toUpperCase(),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: Icon(
                          isBusy ? Icons.block : Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          settings.t(isBusy ? 'Unavailable' : 'Available'),
                        ),
                        backgroundColor: isBusy
                            ? Colors.red.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            label: settings.t('Active services'),
                            value: listings.length.toString(),
                          ),
                          _MetricChip(
                            label: settings.t('Bids won'),
                            value: wonBids.toString(),
                          ),
                          _MetricChip(
                            label: settings.t('Completed reviews'),
                            value: ratings.length.toString(),
                          ),
                        ],
                      ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: categories
                              .map((category) => Chip(label: Text(category)))
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(settings.t('Services'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (listings.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(settings.t('No active services')),
                  ),
                )
              else
                ...listings.map(
                  (listing) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(listing.title),
                      subtitle: Text(
                        '${listing.location} - ${formatMoney(listing.priceMin, currencyCode)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${RouteNames.listingDetail}/${listing.id}?fromArtisan=$artisanId',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(settings.t('Comments'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (ratings.where((rating) => rating.comment.isNotEmpty).isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.comment_outlined),
                    title: Text(settings.t('No comments yet')),
                  ),
                )
              else
                ...ratings.where((rating) => rating.comment.isNotEmpty).map(
                      (rating) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: Text('${rating.stars}/5'),
                          subtitle: Text(rating.comment),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$value $label'),
      side: BorderSide(color: Theme.of(context).dividerColor),
    );
  }
}
