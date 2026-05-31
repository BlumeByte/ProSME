import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../../models/listing.dart';

class ListingFeedScreen extends ConsumerStatefulWidget {
  const ListingFeedScreen({super.key, this.onOpenChatTab});

  final VoidCallback? onOpenChatTab;

  @override
  ConsumerState<ListingFeedScreen> createState() => _ListingFeedScreenState();
}

class _ListingFeedScreenState extends ConsumerState<ListingFeedScreen> {
  final _serviceController = TextEditingController();
  final _locationController = TextEditingController();
  String _serviceQuery = '';
  String _locationQuery = '';

  @override
  void dispose() {
    _serviceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _serviceQuery = _serviceController.text.trim().toLowerCase();
      _locationQuery = _locationController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final listingService = ref.watch(listingServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Listing>>(
      stream: listingService.watchListings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snapshot.data!;
        final filtered = listings.where((listing) {
          final serviceText =
              '${listing.title} ${listing.description} ${listing.category}'
                  .toLowerCase();
          final locationText = listing.location.toLowerCase();
          final serviceMatches =
              _serviceQuery.isEmpty || serviceText.contains(_serviceQuery);
          final locationMatches =
              _locationQuery.isEmpty || locationText.contains(_locationQuery);
          return serviceMatches && locationMatches;
        }).toList(growable: false);

        final categoryCounts = <String, int>{};
        for (final listing in filtered) {
          final category = listing.category.trim().isEmpty
              ? 'Other'
              : listing.category.trim();
          categoryCounts.update(category, (value) => value + 1, ifAbsent: () => 1);
        }
        final popular = categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final professionalsById = <String, _ProfessionalPreview>{};
        for (final listing in filtered) {
          final existing = professionalsById[listing.artisanId];
          if (existing == null) {
            professionalsById[listing.artisanId] = _ProfessionalPreview(
              artisanId: listing.artisanId,
              listingId: listing.id,
              name: (listing.artisanName?.trim().isNotEmpty ?? false)
                  ? listing.artisanName!.trim()
                  : 'Professional',
              avatarUrl: listing.artisanPhotoUrl,
              location: listing.location,
              minPrice: listing.priceMin,
              categories: {listing.category},
              isVerified: listing.verifiedOnly,
              listingCount: 1,
            );
            continue;
          }
          professionalsById[listing.artisanId] = existing.copyWith(
            location: existing.location.isNotEmpty ? existing.location : listing.location,
            minPrice: listing.priceMin < existing.minPrice
                ? listing.priceMin
                : existing.minPrice,
            categories: {...existing.categories, listing.category},
            isVerified: existing.isVerified || listing.verifiedOnly,
            listingCount: existing.listingCount + 1,
          );
        }

        final featured = professionalsById.values.toList()
          ..sort((a, b) => b.listingCount.compareTo(a.listingCount));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _serviceController,
              decoration: const InputDecoration(
                hintText: 'What service do you need?',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'Enter your location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: _applySearch,
                child: const Text('Search'),
              ),
            ),
            const SizedBox(height: 22),
            Text('Popular Services', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (popular.isEmpty)
              const Text('No services available yet.')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: popular.length > 6 ? 6 : popular.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final item = popular[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_categoryEmoji(item.key), style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 8),
                          Text(
                            item.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text('${item.value} pros',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Featured Professionals',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _serviceController.clear();
                    _locationController.clear();
                    _applySearch();
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (featured.isEmpty)
              const Text('No professionals found for this search.')
            else
              ...featured.take(5).map(
                    (pro) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: (pro.avatarUrl?.isNotEmpty ?? false)
                                      ? NetworkImage(pro.avatarUrl!)
                                      : null,
                                  child: (pro.avatarUrl?.isNotEmpty ?? false)
                                      ? null
                                      : Text(
                                          (pro.name.isNotEmpty
                                                  ? pro.name[0]
                                                  : 'P')
                                              .toUpperCase(),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              pro.name,
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                          ),
                                          if (pro.isVerified)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: scheme.primary.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Verified',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pro.location,
                                        style: TextStyle(color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pro.listingCount} active service${pro.listingCount == 1 ? '' : 's'}',
                                        style: TextStyle(color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: pro.categories
                                  .where((item) => item.trim().isNotEmpty)
                                  .take(3)
                                  .map((item) => Chip(label: Text(item)))
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'GHS ${pro.minPrice.toStringAsFixed(0)}/hour',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (user == null) {
                                      context.go(RouteNames.auth);
                                      return;
                                    }
                                    widget.onOpenChatTab?.call();
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Chat'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
                                  ),
                                  onPressed: () {
                                    if (user == null) {
                                      context.go(RouteNames.auth);
                                      return;
                                    }
                                    context.go('${RouteNames.listingDetail}/${pro.listingId}');
                                  },
                                  child: const Text('Book Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _ProfessionalPreview {
  const _ProfessionalPreview({
    required this.artisanId,
    required this.listingId,
    required this.name,
    required this.avatarUrl,
    required this.location,
    required this.minPrice,
    required this.categories,
    required this.isVerified,
    required this.listingCount,
  });

  final String artisanId;
  final String listingId;
  final String name;
  final String? avatarUrl;
  final String location;
  final double minPrice;
  final Set<String> categories;
  final bool isVerified;
  final int listingCount;

  _ProfessionalPreview copyWith({
    String? location,
    double? minPrice,
    Set<String>? categories,
    bool? isVerified,
    int? listingCount,
  }) {
    return _ProfessionalPreview(
      artisanId: artisanId,
      listingId: listingId,
      name: name,
      avatarUrl: avatarUrl,
      location: location ?? this.location,
      minPrice: minPrice ?? this.minPrice,
      categories: categories ?? this.categories,
      isVerified: isVerified ?? this.isVerified,
      listingCount: listingCount ?? this.listingCount,
    );
  }
}

String _categoryEmoji(String category) {
  final normalized = category.toLowerCase();
  if (normalized.contains('plumb')) return '🔧';
  if (normalized.contains('elect')) return '⚡';
  if (normalized.contains('clean')) return '🧽';
  if (normalized.contains('paint')) return '🎨';
  if (normalized.contains('garden')) return '🌱';
  if (normalized.contains('carpen') || normalized.contains('wood')) return '🪚';
  if (normalized.contains('repair')) return '🛠️';
  return '🧰';
}
