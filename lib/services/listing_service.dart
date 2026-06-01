import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/listing.dart';

abstract class ListingService {
  Stream<List<Listing>> watchListings();
  Future<List<Listing>> fetchListings();
  Future<Listing> createListing(Listing listing);
}

class MockListingService implements ListingService {
  final StreamController<List<Listing>> _controller =
      StreamController<List<Listing>>.broadcast();
  final List<Listing> _listings = [];

  @override
  Stream<List<Listing>> watchListings() async* {
    yield List<Listing>.from(_listings);
    yield* _controller.stream;
  }

  @override
  Future<List<Listing>> fetchListings() async => List<Listing>.from(_listings);

  @override
  Future<Listing> createListing(Listing listing) async {
    _listings.insert(0, listing);
    _controller.add(List<Listing>.unmodifiable(_listings));
    return listing;
  }
}

class SupabaseListingService implements ListingService {
  SupabaseListingService(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Listing>> _hydrateListings(List<Map<String, dynamic>> rows) async {
    final artisanIds = rows
        .map(
          (row) => (row['artisan_id'] ?? row['artisanId'])?.toString() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    Map<String, String> artisanNames = {};
    Map<String, String> artisanAvatars = {};
    if (artisanIds.isNotEmpty) {
      try {
        final List<dynamic> profiles = await _supabase
            .from('profiles')
            .select('id,full_name,avatar_url,verification_status')
            .inFilter('id', artisanIds);

        artisanNames = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString():
                ((profile['full_name'] ?? '') as String),
        };
        artisanAvatars = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString():
                ((profile['avatar_url'] ?? '') as String),
        };
        final artisanVerified = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString():
                (profile['verification_status'] ?? '').toString() ==
                    VerificationStatus.verified.name,
        };
        for (final row in rows) {
          final artisanId = (row['artisan_id'] ?? row['artisanId'])?.toString();
          if (artisanId != null && artisanVerified.containsKey(artisanId)) {
            row['verified_only'] = artisanVerified[artisanId] ?? false;
          }
        }
      } catch (error, stackTrace) {
        debugPrint('Failed to load artisan profiles for listings: $error');
        debugPrintStack(stackTrace: stackTrace);
        artisanNames = {};
        artisanAvatars = {};
      }
    }

    return rows.map((row) {
      final artisanId = (row['artisan_id'] ?? row['artisanId'])?.toString();
      final hydratedRow = Map<String, dynamic>.from(row);
      if (artisanId != null && artisanNames.containsKey(artisanId)) {
        hydratedRow['artisanName'] = artisanNames[artisanId];
      }
      if (artisanId != null && artisanAvatars.containsKey(artisanId)) {
        hydratedRow['artisanPhotoUrl'] = artisanAvatars[artisanId];
      }
      return Listing.fromJson(hydratedRow);
    }).toList();
  }

  @override
  Stream<List<Listing>> watchListings() {
    return _supabase.from('listings').stream(primaryKey: ['id']).asyncMap(
      (rows) => _hydrateListings(
        rows.map((row) => Map<String, dynamic>.from(row)).toList(),
      ),
    );
  }

  @override
  Future<List<Listing>> fetchListings() async {
    final List<dynamic> response = await _supabase.from('listings').select();
    return _hydrateListings(
      response
          .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<Listing> createListing(Listing listing) async {
    final row = await _supabase
        .from('listings')
        .insert({
          'artisan_id': listing.artisanId,
          'title': listing.title,
          'description': listing.description,
          'category': listing.category,
          'price_min': listing.priceMin,
          'price_max': listing.priceMax,
          'images': listing.images,
          'location': listing.location,
          'verified_only': listing.verifiedOnly,
        })
        .select()
        .single();
    final hydrated = await _hydrateListings([Map<String, dynamic>.from(row)]);
    return hydrated.first;
  }
}

ListingService buildListingService(SupabaseClient supabase) {
  return kDevMode ? MockListingService() : SupabaseListingService(supabase);
}
