import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../models/listing.dart';
import '../../services/service_providers.dart';

class ListingManageScreen extends ConsumerWidget {
  const ListingManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Center(child: Text('Sign in to manage listings.'));
    }

    final listingService = ref.watch(listingServiceProvider);
    return StreamBuilder<List<Listing>>(
      stream: listingService.watchListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load listings. Check Supabase credentials and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final listings = snapshot.data!
            .where((listing) => listing.artisanId == user.id)
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Listings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: user.verificationStatus == VerificationStatus.verified
                      ? () => _openCreateListingSheet(context, ref)
                      : () => _showVerificationRequired(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (listings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No listings yet. Create your first service listing.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...listings.map(
                (listing) => Card(
                  child: ListTile(
                    title: Text(listing.title),
                    subtitle: Text(
                      '${listing.category} - ${listing.location}\n$kCurrencySymbol ${listing.priceMin.toStringAsFixed(2)} - ${listing.priceMax.toStringAsFixed(2)}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

void _showVerificationRequired(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Verification required'),
      content: const Text(
        'Only admin-verified artisans can publish services. Submit your ID for review first.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _openCreateListingSheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final locationController = TextEditingController();
  final priceMinController = TextEditingController();
  final priceMaxController = TextEditingController();
  final imageUrlController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  const uuid = Uuid();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create listing', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Service title'),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceMinController,
                        decoration: const InputDecoration(labelText: 'Min price'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _positiveMoney,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: priceMaxController,
                        decoration: const InputDecoration(labelText: 'Max price'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _positiveMoney,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final user = ref.read(authStateProvider).valueOrNull;
                      if (user == null) return;

                      final minPrice = double.parse(priceMinController.text.trim());
                      final maxPrice = double.parse(priceMaxController.text.trim());
                      if (maxPrice < minPrice) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Max price must be greater than min price.'),
                          ),
                        );
                        return;
                      }

                      final imageUrl = imageUrlController.text.trim();
                      final listing = Listing(
                        id: uuid.v4(),
                        artisanId: user.id,
                        artisanName: user.name,
                        artisanPhotoUrl: user.photoUrl,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        category: categoryController.text.trim(),
                        priceMin: minPrice,
                        priceMax: maxPrice,
                        images: imageUrl.isEmpty ? const [] : [imageUrl],
                        location: locationController.text.trim(),
                        verifiedOnly: true,
                        createdAt: DateTime.now(),
                      );

                      try {
                        await ref.read(listingServiceProvider).createListing(listing);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Listing created.')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not create listing. Check Supabase setup.'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Create listing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  titleController.dispose();
  descriptionController.dispose();
  categoryController.dispose();
  locationController.dispose();
  priceMinController.dispose();
  priceMaxController.dispose();
  imageUrlController.dispose();
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Required' : null;
}

String? _positiveMoney(String? value) {
  final amount = double.tryParse((value ?? '').trim());
  if (amount == null || amount <= 0) return 'Enter a valid amount';
  return null;
}
