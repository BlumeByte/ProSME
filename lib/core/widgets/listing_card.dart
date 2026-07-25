import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../utils/currency.dart';
import '../../models/listing.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.currencyCode = 'GHS',
  });

  final Listing listing;
  final VoidCallback onTap;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.images.isNotEmpty ? listing.images.first : null;
    final hasArtisanName = listing.artisanName?.trim().isNotEmpty ?? false;
    final displayArtisan =
        hasArtisanName ? listing.artisanName! : listing.artisanId;
    final colors = Theme.of(context).appColors;

    return InkWell(
      onTap: onTap,
      child: Card(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl == null
                  ? Container(
                      width: 96,
                      height: 96,
                      color: colors.surfaceAlt,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.textMuted,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: colors.surfaceAlt,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(listing.location),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMoney(listing.priceMin, currencyCode, decimals: 0)} - ${formatMoney(listing.priceMax, currencyCode, decimals: 0)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Artisan: $displayArtisan',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.ratingAverage.toStringAsFixed(1)}/5 (${listing.ratingCount}) - ${listing.wonBidCount} won bids',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (listing.verifiedOnly)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.verified, color: colors.verified),
              ),
          ],
        ),
      ),
    );
  }
}
