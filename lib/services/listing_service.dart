import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/listing.dart';
import 'db_service.dart';

abstract class ListingService {
  Stream<List<Listing>> watchListings();
  Future<List<Listing>> fetchListings();
  Future<Listing> createListing(Listing listing);
  Future<Listing> updateListing(Listing listing);
  Future<void> deleteListing(String listingId);
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

  @override
  Future<Listing> updateListing(Listing listing) async {
    final index = _listings.indexWhere((item) => item.id == listing.id);
    if (index == -1) return createListing(listing);
    _listings[index] = listing;
    _controller.add(List<Listing>.unmodifiable(_listings));
    return listing;
  }

  @override
  Future<void> deleteListing(String listingId) async {
    _listings.removeWhere((listing) => listing.id == listingId);
    _controller.add(List<Listing>.unmodifiable(_listings));
  }
}

class SupabaseListingService implements ListingService {
  SupabaseListingService(this._supabase, [this._localDb]);

  final SupabaseClient _supabase;
  final LocalDbService? _localDb;

  Future<List<Listing>> _hydrateListings(
      List<Map<String, dynamic>> rows) async {
    final artisanIds = rows
        .map(
          (row) => (row['artisan_id'] ?? row['artisanId'])?.toString() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    Map<String, String> artisanNames = {};
    Map<String, String> artisanAvatars = {};
    Map<String, bool> artisanBusy = {};
    Map<String, double> ratingAverages = {};
    Map<String, int> ratingCounts = {};
    Map<String, int> wonBidCounts = {};
    if (artisanIds.isNotEmpty) {
      try {
        final List<dynamic> profiles = await _supabase
            .from('profiles')
            .select(
                'id,username,full_name,avatar_url,verification_status,is_busy')
            .inFilter('id', artisanIds);
        final List<dynamic> ratings = await _supabase
            .from('job_ratings')
            .select('artisan_id,stars')
            .inFilter('artisan_id', artisanIds);
        final List<dynamic> acceptedBids = await _supabase
            .from('job_bids')
            .select('artisan_id')
            .inFilter('artisan_id', artisanIds)
            .eq('status', 'accepted');

        artisanNames = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString():
                ((profile['username'] ?? profile['full_name'] ?? '') as String),
        };
        artisanAvatars = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString():
                ((profile['avatar_url'] ?? '') as String),
        };
        artisanBusy = {
          for (final profile in profiles)
            (profile['id'] ?? '').toString(): profile['is_busy'] == true,
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
        final ratingTotals = <String, int>{};
        for (final row in ratings) {
          final rating = Map<String, dynamic>.from(row as Map);
          final artisanId = (rating['artisan_id'] ?? '').toString();
          final stars = (rating['stars'] as num?)?.toInt() ?? 0;
          if (artisanId.isEmpty || stars <= 0) continue;
          ratingTotals.update(artisanId, (value) => value + stars,
              ifAbsent: () => stars);
          ratingCounts.update(artisanId, (value) => value + 1,
              ifAbsent: () => 1);
        }
        ratingAverages = {
          for (final entry in ratingTotals.entries)
            entry.key: entry.value / (ratingCounts[entry.key] ?? 1),
        };
        for (final row in acceptedBids) {
          final bid = Map<String, dynamic>.from(row as Map);
          final artisanId = (bid['artisan_id'] ?? '').toString();
          if (artisanId.isEmpty) continue;
          wonBidCounts.update(artisanId, (value) => value + 1,
              ifAbsent: () => 1);
        }
      } catch (error, stackTrace) {
        debugPrint('Failed to load artisan profiles for listings: $error');
        debugPrintStack(stackTrace: stackTrace);
        artisanNames = {};
        artisanAvatars = {};
        artisanBusy = {};
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
      if (artisanId != null && artisanBusy.containsKey(artisanId)) {
        hydratedRow['artisanBusy'] = artisanBusy[artisanId] ?? false;
      }
      if (artisanId != null) {
        hydratedRow['ratingAverage'] = ratingAverages[artisanId] ?? 0;
        hydratedRow['ratingCount'] = ratingCounts[artisanId] ?? 0;
        hydratedRow['wonBidCount'] = wonBidCounts[artisanId] ?? 0;
      }
      return Listing.fromJson(hydratedRow);
    }).toList();
  }

  @override
  Stream<List<Listing>> watchListings() {
    late final StreamController<List<Listing>> controller;
    Timer? refreshTimer;
    var lastEmitted = const <Listing>[];

    void emitIfChanged(List<Listing> listings) {
      if (_listingListsEqual(lastEmitted, listings)) return;
      lastEmitted = List<Listing>.unmodifiable(listings);
      if (!controller.isClosed) controller.add(lastEmitted);
    }

    Future<void> refresh() async {
      try {
        final listings = await fetchListings();
        if (_localDb != null) {
          await _localDb.cacheListings(listings);
        }
        emitIfChanged(listings);
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh listings: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    controller = StreamController<List<Listing>>.broadcast(
      onListen: () async {
        final cached = await _localDb?.loadCachedListings() ?? const [];
        emitIfChanged(cached);
        unawaited(refresh());
        refreshTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () {
        refreshTimer?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<Listing>> fetchListings() async {
    final List<dynamic> response = await _supabase
        .from('listings')
        .select()
        .order('created_at', ascending: false);
    final listings = await _hydrateListings(
      response
          .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
          .toList(),
    );
    if (_localDb != null) {
      await _localDb.cacheListings(listings);
    }
    return listings;
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
    if (_localDb != null) {
      final cached = await _localDb.loadCachedListings();
      await _localDb.cacheListings([hydrated.first, ...cached]);
    }
    return hydrated.first;
  }

  @override
  Future<Listing> updateListing(Listing listing) async {
    final row = await _supabase
        .from('listings')
        .update({
          'title': listing.title,
          'description': listing.description,
          'category': listing.category,
          'price_min': listing.priceMin,
          'price_max': listing.priceMax,
          'images': listing.images,
          'location': listing.location,
          'verified_only': listing.verifiedOnly,
        })
        .eq('id', listing.id)
        .eq('artisan_id', listing.artisanId)
        .select()
        .single();
    final hydrated = await _hydrateListings([Map<String, dynamic>.from(row)]);
    if (_localDb != null) {
      final cached = await _localDb.loadCachedListings();
      final next = [
        for (final item in cached)
          if (item.id == hydrated.first.id) hydrated.first else item,
      ];
      await _localDb.cacheListings(next);
    }
    return hydrated.first;
  }

  @override
  Future<void> deleteListing(String listingId) async {
    await _supabase.from('listings').delete().eq('id', listingId);
    if (_localDb != null) {
      final cached = await _localDb.loadCachedListings();
      await _localDb.cacheListings(
        cached.where((listing) => listing.id != listingId).toList(),
      );
    }
  }

  static bool _listingListsEqual(List<Listing> a, List<Listing> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index += 1) {
      if (a[index].toJson().toString() != b[index].toJson().toString()) {
        return false;
      }
    }
    return true;
  }
}

ListingService buildListingService(SupabaseClient supabase) {
  return kDevMode ? MockListingService() : SupabaseListingService(supabase);
}
