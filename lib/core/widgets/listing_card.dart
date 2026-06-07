import 'package:flutter/material.dart';
import '../../models/listing.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.images.isNotEmpty ? listing.images.first : null;
    final hasArtisanName = listing.artisanName?.trim().isNotEmpty ?? false;
    final displayArtisan =
        hasArtisanName ? listing.artisanName! : listing.artisanId;

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
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    )
                  : Image.network(
                      imageUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
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
                    'GHS ${listing.priceMin.toStringAsFixed(0)} - ${listing.priceMax.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Artisan: $displayArtisan',
                  ),
                ],
              ),
            ),
            if (listing.verifiedOnly)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.verified, color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
