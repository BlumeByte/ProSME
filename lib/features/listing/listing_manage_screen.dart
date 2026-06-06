import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                  onPressed: () => _openCreateListingSheet(context, ref),
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

Future<void> _openCreateListingSheet(
    BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final locationController = TextEditingController();
  final priceMinController = TextEditingController();
  final priceMaxController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final selectedImages = <Uint8List>[];
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
            child: StatefulBuilder(
              builder: (context, setSheetState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create listing',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Service title'),
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
                          decoration:
                              const InputDecoration(labelText: 'Min price'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _positiveMoney,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: priceMaxController,
                          decoration:
                              const InputDecoration(labelText: 'Max price'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _positiveMoney,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: selectedImages.length >= 3
                        ? null
                        : () async {
                            final next = await _pickListingImages(
                              remaining: 3 - selectedImages.length,
                            );
                            setSheetState(() => selectedImages.addAll(next));
                          },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      selectedImages.isEmpty
                          ? 'Upload images'
                          : '${selectedImages.length}/3 images selected',
                    ),
                  ),
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedImages[index],
                                width: 120,
                                height: 68,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setSheetState(
                                    () => selectedImages.removeAt(index),
                                  );
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final user = ref.read(authStateProvider).valueOrNull;
                        if (user == null) return;

                        final minPrice =
                            double.parse(priceMinController.text.trim());
                        final maxPrice =
                            double.parse(priceMaxController.text.trim());
                        if (maxPrice < minPrice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Max price must be greater than min price.'),
                            ),
                          );
                          return;
                        }

                        try {
                          final imageUrls = await _uploadListingImages(
                            ref,
                            user.id,
                            selectedImages,
                          );
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
                            images: imageUrls,
                            location: locationController.text.trim(),
                            verifiedOnly: user.verificationStatus ==
                                VerificationStatus.verified,
                            createdAt: DateTime.now(),
                          );
                          await ref
                              .read(listingServiceProvider)
                              .createListing(listing);
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
                                content: Text(
                                  'Could not create listing. Check Supabase setup.',
                                ),
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
}

Future<List<Uint8List>> _pickListingImages({required int remaining}) async {
  final picker = ImagePicker();
  final files = await picker.pickMultiImage(limit: remaining);
  final output = <Uint8List>[];
  for (final file in files.take(remaining)) {
    final bytes = await file.readAsBytes();
    final processed = _cropAndCompressLandscape(bytes);
    if (processed != null) output.add(processed);
  }
  return output;
}

Uint8List? _cropAndCompressLandscape(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return null;
  const ratio = 16 / 9;
  var cropWidth = decoded.width;
  var cropHeight = (cropWidth / ratio).round();
  if (cropHeight > decoded.height) {
    cropHeight = decoded.height;
    cropWidth = (cropHeight * ratio).round();
  }
  final cropped = image_lib.copyCrop(
    decoded,
    x: ((decoded.width - cropWidth) / 2).round(),
    y: ((decoded.height - cropHeight) / 2).round(),
    width: cropWidth,
    height: cropHeight,
  );
  var width = cropWidth > 1280 ? 1280 : cropWidth;
  for (final quality in [82, 72, 62, 52, 42, 35]) {
    final resized = image_lib.copyResize(cropped, width: width);
    final encoded =
        Uint8List.fromList(image_lib.encodeJpg(resized, quality: quality));
    if (encoded.length <= 100 * 1024) return encoded;
    width = (width * 0.85).round();
  }
  final resized = image_lib.copyResize(cropped, width: 640);
  return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 32));
}

Future<List<String>> _uploadListingImages(
  WidgetRef ref,
  String userId,
  List<Uint8List> images,
) async {
  if (images.isEmpty || !shouldUseSupabase()) return const [];
  final client = ref.read(supabaseClientProvider);
  final urls = <String>[];
  for (var i = 0; i < images.length; i++) {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
    await client.storage.from('listing-images').uploadBinary(
          path,
          images[i],
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    urls.add(client.storage.from('listing-images').getPublicUrl(path));
  }
  return urls;
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Required' : null;
}

String? _positiveMoney(String? value) {
  final amount = double.tryParse((value ?? '').trim());
  if (amount == null || amount <= 0) return 'Enter a valid amount';
  return null;
}
