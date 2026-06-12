import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/listing_card.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/listing.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Saved listings'),
      ),
      body: user == null
          ? const EmptyState(
              title: 'Saved items',
              subtitle: 'Sign in to see your bookmarked listings.',
            )
          : _SavedBody(userId: user.id),
    );
  }
}

class _SavedBody extends ConsumerWidget {
  const _SavedBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIdsAsync = ref.watch(savedListingIdsProvider(userId));
    final currencyCode = ref.watch(appSettingsControllerProvider).currencyCode;

    return savedIdsAsync.when(
      loading: () => const LoadingState(label: 'Loading saved listings…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (savedIds) {
        if (savedIds.isEmpty) {
          return const EmptyState(
            title: 'No saved listings',
            subtitle: 'Tap the bookmark icon on any listing to save it here.',
          );
        }

        final listingService = ref.watch(listingServiceProvider);
        return FutureBuilder<List<Listing>>(
          future: listingService.fetchListings(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LoadingState(label: 'Loading saved listings…');
            }
            final saved = snapshot.data!
                .where((l) => savedIds.contains(l.id))
                .toList(growable: false);

            if (saved.isEmpty) {
              return const EmptyState(
                title: 'No saved listings',
                subtitle:
                    'Tap the bookmark icon on any listing to save it here.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              itemBuilder: (context, index) {
                final listing = saved[index];
                return ListingCard(
                  listing: listing,
                  currencyCode: currencyCode,
                  onTap: () =>
                      context.push('${RouteNames.listingDetail}/${listing.id}'),
                );
              },
            );
          },
        );
      },
    );
  }
}
