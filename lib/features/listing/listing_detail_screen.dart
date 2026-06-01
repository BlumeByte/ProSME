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
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load this listing. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const LoadingState(label: 'Loading listing...');
          }
          final listings = snapshot.data!;
          if (listings.isEmpty) {
            return const Center(child: Text('This listing is no longer available.'));
          }
          Listing? listing;
          for (final item in listings) {
            if (item.id == listingId) {
              listing = item;
              break;
            }
          }
          if (listing == null) {
            return const Center(child: Text('This listing is no longer available.'));
          }
          final previewImageUrl =
              listing.images.isNotEmpty ? listing.images.first : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: listing.images.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 48),
                      )
                    : PageView(
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
                onPressed: () async {
                  if (user == null) {
                    context.go(RouteNames.auth);
                    return;
                  }
                  try {
                    final thread = await ref.read(chatServiceProvider).createOrOpenThread(
                          userId: user.id,
                          artisanId: listing.artisanId,
                        );
                    if (context.mounted) {
                      context.go('${RouteNames.chatThread}/${thread.id}');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not start chat. Please try again.'),
                        ),
                      );
                    }
                  }
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
