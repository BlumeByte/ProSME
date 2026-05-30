import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/listing_card.dart';
import '../../core/widgets/loading_state.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class ListingFeedScreen extends ConsumerWidget {
  const ListingFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingService = ref.watch(listingServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search services',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              SizedBox(width: 16),
              _CategoryChip(label: 'Plumbing'),
              _CategoryChip(label: 'Electrical'),
              _CategoryChip(label: 'Carpentry'),
              _CategoryChip(label: 'Cleaning'),
              _CategoryChip(label: 'Repairs'),
              SizedBox(width: 16),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder(
            stream: listingService.watchListings(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LoadingState(label: 'Loading listings...');
              }
              final listings = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  return ListingCard(
                    listing: listing,
                    onTap: () {
                      if (user == null) {
                        context.go(RouteNames.auth);
                        return;
                      }
                      context.go('${RouteNames.listingDetail}/${listing.id}');
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.category, size: 18),
      ),
    );
  }
}
