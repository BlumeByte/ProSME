import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/loading_state.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import '../../models/listing.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingService = ref.watch(listingServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    // Watch saved IDs in real-time when the user is logged in.
    final savedIds = user == null
        ? const <String>[]
        : ref.watch(savedListingIdsProvider(user.id)).valueOrNull ?? const [];
    final isSaved = savedIds.contains(listingId);

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: FutureBuilder<List<Listing>>(
        future: listingService.fetchListings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingState(label: 'Loading listing...');
          }
          final listing = snapshot.data!.firstWhere(
            (item) => item.id == listingId,
            orElse: () => snapshot.data!.first,
          );
          final previewImageUrl =
              listing.images.isNotEmpty ? listing.images.first : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: PageView(
                  children: listing.images
                      .map((url) => ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(listing.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(listing.description),
              const SizedBox(height: 16),
              Text(
                '${formatCurrency(listing.priceMin)} - ${formatCurrency(listing.priceMax)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 8),
                  Text(listing.location),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    previewImageUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.map_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Chat',
                icon: Icons.chat,
                onPressed: () {
                  if (user == null) {
                    context.go(RouteNames.auth);
                    return;
                  }
                  final threadId = _buildThreadId(user.id, listing.artisanId);
                  context.go('${RouteNames.chatThread}/$threadId');
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Request Invoice',
                icon: Icons.receipt_long,
                onPressed: () => context.go(RouteNames.invoice, extra: listing),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: isSaved ? 'Bookmarked' : 'Bookmark',
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                onPressed: () async {
                  if (user == null) {
                    context.go(RouteNames.auth);
                    return;
                  }
                  final savedService = ref.read(savedServiceProvider);
                  if (isSaved) {
                    await savedService.unsaveListing(user.id, listingId);
                  } else {
                    await savedService.saveListing(user.id, listingId);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

String _buildThreadId(String userId, String artisanId) {
  final pair = [userId, artisanId]..sort();
  return 'thread_${pair.join('_')}';
}
