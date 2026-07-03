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
  final StreamController<List<Listing>> _controller =
      StreamController<List<Listing>>.broadcast();
  List<Listing> _latest = const [];
  bool _started = false;

  static String _profileDisplayName(dynamic profile) {
    final row = Map<String, dynamic>.from(profile as Map);
    for (final key in ['full_name', 'username', 'email']) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      if (key == 'email') return value.split('@').first;
      return value;
    }
    return '';
  }

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
                'id,username,full_name,email,avatar_url,verification_status,is_busy')
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
            (profile['id'] ?? '').toString(): _profileDisplayName(profile),
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
    _ensureStarted();
    return Stream<List<Listing>>.multi((controller) {
      controller.add(List<Listing>.unmodifiable(_latest));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(() async {
      final cached = await _localDb?.loadCachedListings() ?? const [];
      _emitListings(cached, force: true);
      await _refreshListings();
    }());
    Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshListings()),
    );
  }

  Future<void> _refreshListings() async {
    try {
      _emitListings(await fetchListings());
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh listings: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_latest.isEmpty) {
        _emitListings(await _localDb?.loadCachedListings() ?? const [],
            force: true);
      }
    }
  }

  void _emitListings(List<Listing> listings, {bool force = false}) {
    final next = List<Listing>.unmodifiable(listings);
    if (!force && _listingListsEqual(_latest, next)) return;
    _latest = next;
    if (!_controller.isClosed) _controller.add(next);
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
    final payload = {
      'artisan_id': listing.artisanId,
      'title': listing.title,
      'description': listing.description,
      'category': listing.category,
      'price_min': listing.priceMin,
      'price_max': listing.priceMax,
      'images': listing.images,
      'location': listing.location,
      'verified_only': listing.verifiedOnly,
    };
    late Listing created;
    try {
      final row =
          await _supabase.from('listings').insert(payload).select().single();
      final hydrated = await _hydrateListings([Map<String, dynamic>.from(row)]);
      created = hydrated.first;
    } catch (error, stackTrace) {
      debugPrint(
        'Listing insert response failed, checking for created row: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      final recovered = await _findLatestMatchingListing(listing);
      if (recovered == null) rethrow;
      created = recovered;
    }
    if (_localDb != null) {
      final cached = await _localDb.loadCachedListings();
      final next = [
        created,
        ...cached.where((item) => item.id != created.id),
      ];
      await _localDb.cacheListings(next);
      _emitListings(next, force: true);
    } else {
      _emitListings(
          [created, ..._latest.where((item) => item.id != created.id)]);
    }
    return created;
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
      if (!next.any((item) => item.id == hydrated.first.id)) {
        next.insert(0, hydrated.first);
      }
      await _localDb.cacheListings(next);
      _emitListings(next, force: true);
    } else {
      final next = [
        for (final item in _latest)
          if (item.id == hydrated.first.id) hydrated.first else item,
      ];
      if (!next.any((item) => item.id == hydrated.first.id)) {
        next.insert(0, hydrated.first);
      }
      _emitListings(next, force: true);
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
      _emitListings(
        cached.where((listing) => listing.id != listingId).toList(),
        force: true,
      );
    } else {
      _emitListings(
        _latest.where((listing) => listing.id != listingId).toList(),
        force: true,
      );
    }
  }

  Future<Listing?> _findLatestMatchingListing(Listing listing) async {
    try {
      final rows = await _supabase
          .from('listings')
          .select()
          .eq('artisan_id', listing.artisanId)
          .eq('title', listing.title)
          .eq('description', listing.description)
          .eq('location', listing.location)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final hydrated = await _hydrateListings(
        [Map<String, dynamic>.from(rows.first as Map)],
      );
      return hydrated.first;
    } catch (error, stackTrace) {
      debugPrint('Failed to recover created listing: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
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
  return kMockMode ? MockListingService() : SupabaseListingService(supabase);
}
