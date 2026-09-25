import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/service_categories.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/listing.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../jobs/jobs_repository.dart';

class ArtisanProfileScreen extends ConsumerWidget {
  const ArtisanProfileScreen({super.key, required this.artisanId});

  final String artisanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsFuture = ref.watch(listingServiceProvider).fetchListings();
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final currencyCode = settings.currencyCode;
    final colors = Theme.of(context).appColors;
    final bids = ref.watch(artisanBidsProvider(artisanId)).valueOrNull ??
        const <JobBid>[];
    final ratings = ref.watch(artisanRatingsProvider(artisanId)).valueOrNull ??
        const <JobRating>[];

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Professional profile')),
      ),
      body: FutureBuilder<List<Listing>>(
        future: listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(settings.t('Could not load professional profile.')),
              ),
            );
          }
          if (!snapshot.hasData) {
            return LoadingState(label: settings.t('Loading profile...'));
          }

          final listings = snapshot.data!
              .where((listing) => listing.artisanId == artisanId)
              .toList(growable: false);
          final first = listings.isEmpty ? null : listings.first;
          final name = first?.artisanName?.trim().isNotEmpty == true
              ? first!.artisanName!.trim()
              : settings.t('Professional');
          final avatarUrl = first?.artisanPhotoUrl;
          final isVerified = listings.any((listing) => listing.verifiedOnly);
          final isBusy = listings.any((listing) => listing.artisanBusy);
          final wonBids = bids.where((bid) => bid.status == 'accepted').length;
          final categories = listings
              .map((listing) => normalizeServiceCategory(listing.category))
              .where((category) => category.trim().isNotEmpty)
              .toSet()
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        foregroundImage: avatarUrl?.trim().isNotEmpty == true
                            ? CachedNetworkImageProvider(avatarUrl!)
                            : null,
                        onForegroundImageError:
                            avatarUrl?.trim().isNotEmpty == true
                                ? (_, __) {}
                                : null,
                        child: Text(
                          name.isEmpty ? 'P' : name[0].toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.verified,
                                color: colors.verified, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: Icon(
                          isBusy ? Icons.block : Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          settings.t(isBusy ? 'Unavailable' : 'Available'),
                        ),
                        backgroundColor: isBusy
                            ? colors.cancelled.withValues(alpha: 0.12)
                            : colors.verified.withValues(alpha: 0.12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            label: settings.t('Active services'),
                            value: listings.length.toString(),
                          ),
                          _MetricChip(
                            label: settings.t('Bids won'),
                            value: wonBids.toString(),
                          ),
                          _MetricChip(
                            label: settings.t('Completed reviews'),
                            value: ratings.length.toString(),
                          ),
                        ],
                      ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: categories
                              .map((category) => Chip(label: Text(category)))
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _openDirectBookingForm(
                                    context,
                                    ref,
                                    artisanId: artisanId,
                                    artisanName: name,
                                    defaultLocation:
                                        first?.location ?? user?.country ?? '',
                                    defaultTitle: categories.isEmpty
                                        ? settings.t('Service request')
                                        : categories.first,
                                  ),
                          icon: const Icon(Icons.request_quote_outlined),
                          label: Text(settings.t('Book now')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(settings.t('Services'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (listings.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(settings.t('No active services')),
                  ),
                )
              else
                ...listings.map(
                  (listing) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(listing.title),
                      subtitle: Text(
                        '${listing.location} - ${formatMoney(listing.priceMin, currencyCode)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${RouteNames.listingDetail}/${listing.id}?fromArtisan=$artisanId',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(settings.t('Comments'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (ratings.where((rating) => rating.comment.isNotEmpty).isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.comment_outlined),
                    title: Text(settings.t('No comments yet')),
                  ),
                )
              else
                ...ratings.where((rating) => rating.comment.isNotEmpty).map(
                      (rating) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: Text('${rating.stars}/5'),
                          subtitle: Text(rating.comment),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _openDirectBookingForm(
  BuildContext context,
  WidgetRef ref, {
  required String artisanId,
  required String artisanName,
  required String defaultLocation,
  required String defaultTitle,
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final settings = ref.read(appSettingsControllerProvider);
  if (user == null) {
    context.go(RouteNames.auth);
    return;
  }
  if (user.role == UserRole.artisan && user.id == artisanId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(settings.t('You cannot book yourself.'))),
    );
    return;
  }

  final titleController = TextEditingController(text: defaultTitle);
  final descriptionController = TextEditingController();
  final locationController = TextEditingController(text: defaultLocation);
  final amountController = TextEditingController();
  final messageController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final currencyCode = settings.currencyCode;

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
                      '${settings.t('Book')} $artisanName',
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
                validator: (value) => _requiredDirect(value, settings),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: settings.t('What do you need done?'),
                ),
                validator: (value) => _requiredDirect(value, settings),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(labelText: settings.t('Location')),
                validator: (value) => _requiredDirect(value, settings),
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
          artisanId: artisanId,
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
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('Could not send booking offer.')),
        ),
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

String? _requiredDirect(String? value, AppSettings settings) {
  return value == null || value.trim().isEmpty ? settings.t('Required') : null;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$value $label'),
      side: BorderSide(color: Theme.of(context).dividerColor),
    );
  }
}
