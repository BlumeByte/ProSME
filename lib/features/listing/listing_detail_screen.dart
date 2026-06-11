import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/safe_back_button.dart';
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
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Listing'),
      ),
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
            return const Center(
                child: Text('This listing is no longer available.'));
          }
          Listing? listing;
          for (final item in listings) {
            if (item.id == listingId) {
              listing = item;
              break;
            }
          }
          if (listing == null) {
            return const Center(
                child: Text('This listing is no longer available.'));
          }
          final listingData = listing;
          final isBusy = listingData.artisanBusy;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: listingData.images.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 48),
                      )
                    : PageView(
                        children: listingData.images
                            .map((url) => ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                          Icons.image_not_supported_outlined),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              Text(listingData.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(listingData.description),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        listingData.artisanPhotoUrl?.trim().isNotEmpty == true
                            ? NetworkImage(listingData.artisanPhotoUrl!)
                            : null,
                    child:
                        listingData.artisanPhotoUrl?.trim().isNotEmpty == true
                            ? null
                            : const Icon(Icons.person_outline),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          listingData.artisanName?.trim().isNotEmpty == true
                              ? listingData.artisanName!
                              : 'Professional',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listingData.verifiedOnly)
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 18),
                    ],
                  ),
                  subtitle: Text(isBusy
                      ? 'Unavailable now'
                      : '${listingData.wonBidCount} won bids'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '${RouteNames.artisanProfile}/${listingData.artisanId}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${formatCurrency(listingData.priceMin)} - ${formatCurrency(listingData.priceMax)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 8),
                  Expanded(child: Text(listingData.location)),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: isBusy ? 'Artisan unavailable' : 'Chat',
                icon: isBusy ? Icons.block : Icons.chat,
                onPressed: () async {
                  if (isBusy) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This artisan is currently unavailable.'),
                      ),
                    );
                    return;
                  }
                  if (user == null) {
                    context.go(RouteNames.auth);
                    return;
                  }
                  if (user.id == listingData.artisanId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot chat with yourself.'),
                      ),
                    );
                    return;
                  }
                  try {
                    final thread =
                        await ref.read(chatServiceProvider).createOrOpenThread(
                              userId: user.id,
                              artisanId: listingData.artisanId,
                            );
                    if (context.mounted) {
                      context.push('${RouteNames.chatThread}/${thread.id}');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Could not start chat. Please try again.'),
                        ),
                      );
                    }
                  }
                },
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
