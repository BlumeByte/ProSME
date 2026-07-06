import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/loading_state.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../../models/listing.dart';
import '../jobs/jobs_repository.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.sourceArtisanId,
  });

  final String listingId;
  final String? sourceArtisanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;

    // Watch saved IDs in real-time when the user is logged in.
    final savedIds = user == null
        ? const <String>[]
        : ref.watch(savedListingIdsProvider(user.id)).valueOrNull ?? const [];
    final isSaved = savedIds.contains(listingId);

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Listing')),
      ),
      body: ref.watch(listingsStreamProvider).when(
            error: (_, __) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    settings.t(
                      'Could not load this listing. Check your connection and try again.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
            loading: () =>
                LoadingState(label: settings.t('Loading listing...')),
            data: (listings) {
              if (listings.isEmpty) {
                return Center(
                  child:
                      Text(settings.t('This listing is no longer available.')),
                );
              }
              Listing? listing;
              for (final item in listings) {
                if (item.id == listingId) {
                  listing = item;
                  break;
                }
              }
              if (listing == null) {
                return Center(
                  child:
                      Text(settings.t('This listing is no longer available.')),
                );
              }
              final listingData = listing;
              final isBusy = listingData.artisanBusy;
              final isSourceProfile = sourceArtisanId == listingData.artisanId;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ListingImageCarousel(images: listingData.images),
                  const SizedBox(height: 16),
                  Text(listingData.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(listingData.description),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        foregroundImage:
                            listingData.artisanPhotoUrl?.trim().isNotEmpty ==
                                    true
                                ? NetworkImage(listingData.artisanPhotoUrl!)
                                : null,
                        onForegroundImageError:
                            listingData.artisanPhotoUrl?.trim().isNotEmpty ==
                                    true
                                ? (_, __) {}
                                : null,
                        child: const Icon(Icons.person_outline),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              listingData.artisanName?.trim().isNotEmpty == true
                                  ? listingData.artisanName!
                                  : settings.t('Professional'),
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
                          ? settings.t('Unavailable now')
                          : '${listingData.wonBidCount} ${settings.t('won bids')}'),
                      trailing: isSourceProfile
                          ? null
                          : const Icon(Icons.chevron_right),
                      onTap: isSourceProfile
                          ? null
                          : () => context.push(
                                '${RouteNames.artisanProfile}/${listingData.artisanId}',
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${formatCurrency(listingData.priceMin, currencyCode: currencyCode)} - ${formatCurrency(listingData.priceMax, currencyCode: currencyCode)}',
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
                    label:
                        settings.t(isBusy ? 'Artisan unavailable' : 'Book now'),
                    icon: isBusy ? Icons.block : Icons.request_quote_outlined,
                    onPressed: () async {
                      if (isBusy) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              settings
                                  .t('This artisan is currently unavailable.'),
                            ),
                          ),
                        );
                        return;
                      }
                      await _openListingBookingForm(
                        context,
                        ref,
                        listing: listingData,
                        currencyCode: currencyCode,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: settings.t(isSaved ? 'Bookmarked' : 'Bookmark'),
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

Future<void> _openListingBookingForm(
  BuildContext context,
  WidgetRef ref, {
  required Listing listing,
  required String currencyCode,
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final settings = ref.read(appSettingsControllerProvider);
  if (user == null) {
    context.go(RouteNames.auth);
    return;
  }
  if (user.role == UserRole.artisan && user.id == listing.artisanId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(settings.t('You cannot book yourself.'))),
    );
    return;
  }

  final titleController = TextEditingController(text: listing.title);
  final descriptionController =
      TextEditingController(text: listing.description);
  final locationController = TextEditingController(text: listing.location);
  final amountController = TextEditingController(
    text: convertFromGhs(listing.priceMin, currencyCode).toStringAsFixed(2),
  );
  final messageController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      settings.t('Send booking offer'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: settings.t('Service')),
                validator: (value) => _requiredBooking(value, settings),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: settings.t('What do you need done?'),
                ),
                validator: (value) => _requiredBooking(value, settings),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(labelText: settings.t('Location')),
                validator: (value) => _requiredBooking(value, settings),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: '${settings.t('Offer price')} ($currencyCode)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return settings.t('Enter a valid price');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: messageController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: settings.t('Offer note (optional)'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: Text(settings.t('Send booking offer')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (submitted != true || !context.mounted) {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    amountController.dispose();
    messageController.dispose();
    return;
  }

  try {
    final result = await ref.read(jobsRepositoryProvider).createDirectBid(
          customerId: user.id,
          artisanId: listing.artisanId,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          location: locationController.text.trim(),
          amount: convertToGhs(
            double.parse(amountController.text.trim()),
            currencyCode,
          ),
          message: messageController.text.trim(),
        );
    ref.invalidate(jobsStreamProvider);
    ref.invalidate(jobBidsProvider(result.job.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Booking offer sent.'))),
      );
      context.push('${RouteNames.jobDetail}/${result.job.id}');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Could not send booking offer.'))),
      );
    }
  } finally {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    amountController.dispose();
    messageController.dispose();
  }
}

String? _requiredBooking(String? value, AppSettings settings) {
  return value == null || value.trim().isEmpty ? settings.t('Required') : null;
}

class _ListingImageCarousel extends StatefulWidget {
  const _ListingImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_ListingImageCarousel> createState() => _ListingImageCarouselState();
}

class _ListingImageCarouselState extends State<_ListingImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (widget.images.isEmpty) return;
    final next = index.clamp(0, widget.images.length - 1);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 48),
      );
    }

    final canGoPrevious = _index > 0;
    final canGoNext = _index < widget.images.length - 1;
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: IconButton.filledTonal(
                onPressed: canGoPrevious ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: IconButton.filledTonal(
                onPressed: canGoNext ? () => _goTo(_index + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _index ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(
                        alpha: index == _index ? 0.95 : 0.55,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
