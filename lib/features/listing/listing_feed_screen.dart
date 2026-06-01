import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../../models/listing.dart';
import '../jobs/domain/jobs_repository.dart' hide jobsStreamProvider;
import '../jobs/application/jobs_providers.dart';

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
  String? _selectedCategory;
  static const _defaultCategories = [
    ('Plumbing', Icons.plumbing, 0),
    ('Electrical', Icons.electrical_services, 0),
    ('Cleaning', Icons.cleaning_services, 0),
    ('Painting', Icons.format_paint, 0),
    ('Gardening', Icons.yard, 0),
    ('Carpentry', Icons.handyman, 0),
  ];

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
      _selectedCategory = null;
    });
  }

  void _applyCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _serviceController.text = category;
      _serviceQuery = category.toLowerCase();
    });
  }

  Future<bool> _confirmUnverified(_ProfessionalPreview pro) async {
    if (pro.isVerified) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unverified artisan'),
            content: Text(
              '${pro.name} has not been verified by ProSME admin yet. Continue only if you are comfortable engaging this artisan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _startChat(_ProfessionalPreview pro) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go(RouteNames.auth);
      return;
    }
    if (!await _confirmUnverified(pro)) return;
    try {
      final thread = await ref.read(chatServiceProvider).createOrOpenThread(
            userId: user.id,
            artisanId: pro.artisanId,
          );
      if (mounted) {
        context.go('${RouteNames.chatThread}/${thread.id}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not start chat. Please try again.')),
      );
    }
  }

  Future<void> _bookProfessional(_ProfessionalPreview pro) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go(RouteNames.auth);
      return;
    }
    if (!await _confirmUnverified(pro)) return;
    if (mounted) {
      context.go('${RouteNames.listingDetail}/${pro.listingId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingService = ref.watch(listingServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Listing>>(
      stream: listingService.watchListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load professionals. Check Supabase credentials and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
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
          final categoryMatches = _selectedCategory == null ||
              listing.category
                  .toLowerCase()
                  .contains(_selectedCategory!.toLowerCase());
          final locationMatches =
              _locationQuery.isEmpty || locationText.contains(_locationQuery);
          return serviceMatches && categoryMatches && locationMatches;
        }).toList(growable: false);

        final categoryCounts = <String, int>{};
        for (final listing in filtered) {
          final category = listing.category.trim().isEmpty
              ? 'Other'
              : listing.category.trim();
          categoryCounts.update(category, (value) => value + 1,
              ifAbsent: () => 1);
        }
        final categoryCards = _defaultCategories.map((item) {
          final count = categoryCounts[item.$1] ?? item.$3;
          return _CategoryPreview(item.$1, item.$2, count);
        }).toList(growable: false);

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
            location: existing.location.isNotEmpty
                ? existing.location
                : listing.location,
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            TextField(
              controller: _serviceController,
              onSubmitted: (_) => _applySearch(),
              decoration: const InputDecoration(
                hintText: 'What service do you need?',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              onSubmitted: (_) => _applySearch(),
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
            Text('Popular Services',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryCards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final item = categoryCards[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _applyCategory(item.name);
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, color: scheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.count} pros',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
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
                    setState(() {
                      _serviceQuery = '';
                      _locationQuery = '';
                      _selectedCategory = null;
                    });
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
                                  backgroundImage:
                                      (pro.avatarUrl?.isNotEmpty ?? false)
                                          ? NetworkImage(pro.avatarUrl!)
                                          : null,
                                  child: (pro.avatarUrl?.isNotEmpty ?? false)
                                      ? null
                                      : Text(
                                          (pro.name.trim().isNotEmpty
                                                  ? pro.name.trim()[0]
                                                  : 'P')
                                              .toUpperCase(),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              pro.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ),
                                          if (pro.isVerified)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: scheme.primary
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
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
                                        style: TextStyle(
                                            color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pro.listingCount} active service${pro.listingCount == 1 ? '' : 's'}',
                                        style: TextStyle(
                                            color: scheme.onSurfaceVariant),
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
                                  'From $kCurrencySymbol ${pro.minPrice.toStringAsFixed(2)}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () => _startChat(pro),
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      size: 18),
                                  label: const Text('Chat'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
                                  ),
                                  onPressed: () => _bookProfessional(pro),
                                  child: const Text('Book Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            Text('Open Service Requests',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _OpenJobsPreview(userId: user?.id),
          ],
        );
      },
    );
  }
}

class _CategoryPreview {
  const _CategoryPreview(this.name, this.icon, this.count);

  final String name;
  final IconData icon;
  final int count;
}

class _OpenJobsPreview extends ConsumerWidget {
  const _OpenJobsPreview({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);
    return jobsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text(
        'Could not load service requests. Check Supabase credentials and try again.',
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return const Text('No service requests posted yet.');
        }
        return Column(
          children: jobs.take(3).map((job) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: job == null
                  ? const SizedBox.shrink()
                  : ListTile(
                      title: Text(job.title),
                      subtitle: Text(
                        '${job.location} - $kCurrencySymbol ${job.budget.toStringAsFixed(2)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: userId == null
                          ? () => context.go(RouteNames.auth)
                          : () =>
                              context.go('${RouteNames.jobDetail}/${job.id}'),
                    ),
            );
          }).toList(growable: false),
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
