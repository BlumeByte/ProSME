import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/service_categories.dart';
import '../../models/listing.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

class ListingManageScreen extends ConsumerWidget {
  const ListingManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    if (user == null) {
      return Center(child: Text(settings.t('Sign in to manage listings.')));
    }

    final listingService = ref.watch(listingServiceProvider);
    return StreamBuilder<List<Listing>>(
      stream: listingService.watchListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                settings.t(
                  'Could not load listings. Please check your connection and try again.',
                ),
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
                    settings.t('My Listings'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openCreateListingSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(settings.t('Create')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (listings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    settings.t(
                      'No listings yet. Create your first service listing.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...listings.map(
                (listing) => Card(
                  child: ListTile(
                    leading: listing.images.isEmpty
                        ? const CircleAvatar(child: Icon(Icons.storefront))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              listing.images.first,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const CircleAvatar(
                                child: Icon(Icons.storefront),
                              ),
                            ),
                          ),
                    title: Text(listing.title),
                    subtitle: Text(
                      '${listing.category} - ${listing.location}\n${formatMoney(listing.priceMin, currencyCode)} - ${formatMoney(listing.priceMax, currencyCode)}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await _openListingSheet(context, ref,
                              existing: listing);
                          return;
                        }
                        if (action == 'delete') {
                          await _deleteListing(context, ref, listing);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(settings.t('Edit')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(settings.t('Delete')),
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

Future<void> _openCreateListingSheet(
    BuildContext context, WidgetRef ref) async {
  await _openListingSheet(context, ref);
}

Future<void> _openListingSheet(
  BuildContext context,
  WidgetRef ref, {
  Listing? existing,
}) async {
  final settings = ref.read(appSettingsControllerProvider);
  final currencyCode = settings.currencyCode;
  final titleController = TextEditingController(text: existing?.title ?? '');
  final descriptionController =
      TextEditingController(text: existing?.description ?? '');
  final otherCategoryController = TextEditingController();
  final locationController =
      TextEditingController(text: existing?.location ?? '');
  final priceMinController = TextEditingController(
    text: existing == null
        ? ''
        : convertFromGhs(existing.priceMin, currencyCode).toStringAsFixed(0),
  );
  final priceMaxController = TextEditingController(
    text: existing == null
        ? ''
        : convertFromGhs(existing.priceMax, currencyCode).toStringAsFixed(0),
  );
  final formKey = GlobalKey<FormState>();
  final selectedImages = <Uint8List>[];
  final existingImages = <String>[...(existing?.images ?? const <String>[])];
  var selectedCategory = kServiceCategories.any(
    (category) => category.name == existing?.category,
  )
      ? existing?.category ?? kServiceCategories.first.name
      : 'Other';
  if (selectedCategory == 'Other' &&
      existing?.category.trim().isNotEmpty == true) {
    otherCategoryController.text = existing!.category;
  }
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
                  Text(
                      settings.t(
                        existing == null ? 'Create listing' : 'Edit listing',
                      ),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration:
                        InputDecoration(labelText: settings.t('Service title')),
                    validator: (value) => _required(value, settings),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration:
                        InputDecoration(labelText: settings.t('Category')),
                    items: kServiceCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.name,
                            child: Text(settings.t(category.name)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedCategory = value);
                    },
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: otherCategoryController,
                      decoration: InputDecoration(
                        labelText: settings.t('Custom category'),
                      ),
                      validator: (value) => _required(value, settings),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 4,
                    decoration:
                        InputDecoration(labelText: settings.t('Description')),
                    validator: (value) => _required(value, settings),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locationController,
                    decoration:
                        InputDecoration(labelText: settings.t('Location')),
                    validator: (value) => _required(value, settings),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceMinController,
                          decoration: InputDecoration(
                            labelText:
                                '${settings.t('Min price')} ($currencyCode)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) => _positiveMoney(value, settings),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: priceMaxController,
                          decoration: InputDecoration(
                            labelText:
                                '${settings.t('Max price')} ($currencyCode)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) => _positiveMoney(value, settings),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final totalImages =
                        existingImages.length + selectedImages.length;
                    final remainingImages = 3 - totalImages;
                    return OutlinedButton.icon(
                      onPressed: remainingImages <= 0
                          ? null
                          : () async {
                              final next = await _pickListingImages(
                                remaining: remainingImages,
                              );
                              setSheetState(() => selectedImages.addAll(next));
                            },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        totalImages == 0
                            ? settings.t('Upload images')
                            : '$totalImages/3 ${settings.t('images selected')}',
                      ),
                    );
                  }),
                  if (existingImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: existingImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                existingImages[index],
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
                                    () => existingImages.removeAt(index),
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

                        final minPrice = convertToGhs(
                          double.parse(priceMinController.text.trim()),
                          currencyCode,
                        );
                        final maxPrice = convertToGhs(
                          double.parse(priceMaxController.text.trim()),
                          currencyCode,
                        );
                        if (maxPrice < minPrice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settings.t(
                                  'Max price must be greater than min price.',
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        List<String> uploadedUrls = const [];
                        try {
                          uploadedUrls = await _uploadListingImages(
                            ref,
                            user.id,
                            selectedImages,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${settings.t('Could not upload listing image')}: $error',
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        try {
                          final category = normalizeServiceCategory(
                              selectedCategory == 'Other'
                                  ? otherCategoryController.text
                                  : selectedCategory);
                          final listing = Listing(
                            id: existing?.id ?? uuid.v4(),
                            artisanId: user.id,
                            artisanName: user.name,
                            artisanPhotoUrl: user.photoUrl,
                            title: titleController.text.trim(),
                            description: descriptionController.text.trim(),
                            category: category,
                            priceMin: minPrice,
                            priceMax: maxPrice,
                            images: [...existingImages, ...uploadedUrls],
                            location: locationController.text.trim(),
                            verifiedOnly: user.verificationStatus ==
                                VerificationStatus.verified,
                            createdAt: existing?.createdAt ?? DateTime.now(),
                          );
                          if (existing == null) {
                            await ref
                                .read(listingServiceProvider)
                                .createListing(listing);
                          } else {
                            await ref
                                .read(listingServiceProvider)
                                .updateListing(listing);
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(existing == null
                                    ? settings.t('Listing created.')
                                    : settings.t('Listing updated.')),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existing == null
                                      ? '${settings.t('Could not create listing')}: $error'
                                      : '${settings.t('Could not save listing')}: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        settings.t(
                          existing == null ? 'Create listing' : 'Save listing',
                        ),
                      ),
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
  otherCategoryController.dispose();
  locationController.dispose();
  priceMinController.dispose();
  priceMaxController.dispose();
}

Future<void> _deleteListing(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  final settings = ref.read(appSettingsControllerProvider);
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(settings.t('Delete listing')),
          content: Text(
            '${settings.t('Delete')} "${listing.title}" ${settings.t('permanently?')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(settings.t('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(settings.t('Delete')),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;
  try {
    await ref.read(listingServiceProvider).deleteListing(listing.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Listing deleted.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not delete listing')}: $error'),
        ),
      );
    }
  }
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
    try {
      await client.storage.from('listing-images').uploadBinary(
            path,
            images[i],
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
    } on StorageException catch (error) {
      throw StateError(
        'Storage bucket "listing-images" is not ready or your account cannot upload to it. ${error.message}',
      );
    }
    urls.add(client.storage.from('listing-images').getPublicUrl(path));
  }
  return urls;
}

String? _required(String? value, AppSettings settings) {
  return value == null || value.trim().isEmpty ? settings.t('Required') : null;
}

String? _positiveMoney(String? value, AppSettings settings) {
  final amount = double.tryParse((value ?? '').trim());
  if (amount == null || amount <= 0) return settings.t('Enter a valid amount');
  return null;
}
