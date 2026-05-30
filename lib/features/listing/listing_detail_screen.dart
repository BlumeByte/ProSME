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
                    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
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
                onPressed: () => context.go('${RouteNames.chatThread}/thread_1'),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Request Invoice',
                icon: Icons.receipt_long,
                onPressed: () => context.go(RouteNames.invoice),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Bookmark',
                icon: Icons.bookmark_border,
                onPressed: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}
