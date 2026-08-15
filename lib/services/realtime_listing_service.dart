import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing.dart';
import 'db_service.dart';
import 'listing_service.dart';

/// Cache-first listing service shared by mobile/web.
///
/// A global Postgres Changes subscription does not scale for a public feed:
/// every listing write must be authorized and fanned out to every connected
/// user. The feed is therefore loaded once per app session, capped to 100 rows,
/// and refreshed after local writes or an explicit [fetchListings] call.
class RealtimeListingService implements ListingService {
  RealtimeListingService(this._supabase, this._localDb);

  final SupabaseClient _supabase;
  final LocalDbService _localDb;
  final StreamController<List<Listing>> _controller =
      StreamController<List<Listing>>.broadcast();

  List<Listing> _latest = const [];
  bool _started = false;
  bool _refreshing = false;
  bool _refreshQueued = false;

  @override
  Stream<List<Listing>> watchListings() {
    _ensureStarted();
    return Stream<List<Listing>>.multi((controller) {
      controller.add(List<Listing>.unmodifiable(_latest));
      final sub = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final cached = await _localDb.loadCachedListings();
      if (cached.isNotEmpty) _emit(cached, force: true);
    } catch (error) {
      debugPrint('Could not read cached listings: $error');
    }

    await _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final data = await fetchListings();
      _emit(data);
    } finally {
      _refreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refresh());
      }
    }
  }

  void _emit(List<Listing> listings, {bool force = false}) {
    final next = List<Listing>.unmodifiable(listings);
    if (!force && _sameIdsAndTimestamps(_latest, next)) return;
    _latest = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  bool _sameIdsAndTimestamps(List<Listing> a, List<Listing> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].toJson().toString() != b[i].toJson().toString()) return false;
    }
    return true;
  }

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
    List<Map<String, dynamic>> rows,
  ) async {
    final artisanIds = rows
        .map((row) => (row['artisan_id'] ?? row['artisanId'])?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (artisanIds.isEmpty) {
      return rows.map(Listing.fromJson).toList(growable: false);
    }

    Map<String, String> artisanNames = {};
    Map<String, String> artisanAvatars = {};
    Map<String, bool> artisanBusy = {};
    Map<String, bool> artisanVerified = {};
    Map<String, double> ratingAverages = {};
    Map<String, int> ratingCounts = {};
    Map<String, int> wonBidCounts = {};

    try {
      final results = await Future.wait<dynamic>([
        _supabase
            .from('profiles')
            .select(
              'id,username,full_name,email,avatar_url,verification_status,is_busy',
            )
            .inFilter('id', artisanIds),
        _supabase
            .from('job_ratings')
            .select('artisan_id,stars')
            .inFilter('artisan_id', artisanIds),
        _supabase
            .from('job_bids')
            .select('artisan_id')
            .inFilter('artisan_id', artisanIds)
            .eq('status', 'accepted'),
      ]);

      final profiles = List<dynamic>.from(results[0] as List);
      final ratings = List<dynamic>.from(results[1] as List);
      final acceptedBids = List<dynamic>.from(results[2] as List);

      artisanNames = {
        for (final profile in profiles)
          (profile['id'] ?? '').toString(): _profileDisplayName(profile),
      };
      artisanAvatars = {
        for (final profile in profiles)
          (profile['id'] ?? '').toString(): (profile['avatar_url'] ?? '')
              .toString(),
      };
      artisanBusy = {
        for (final profile in profiles)
          (profile['id'] ?? '').toString(): profile['is_busy'] == true,
      };
      artisanVerified = {
        for (final profile in profiles)
          (profile['id'] ?? '').toString():
              (profile['verification_status'] ?? '').toString() == 'verified',
      };

      final ratingTotals = <String, int>{};
      for (final value in ratings) {
        final rating = Map<String, dynamic>.from(value as Map);
        final artisanId = (rating['artisan_id'] ?? '').toString();
        final stars = (rating['stars'] as num?)?.toInt() ?? 0;
        if (artisanId.isEmpty || stars <= 0) continue;
        ratingTotals.update(
          artisanId,
          (current) => current + stars,
          ifAbsent: () => stars,
        );
        ratingCounts.update(
          artisanId,
          (current) => current + 1,
          ifAbsent: () => 1,
        );
      }
      ratingAverages = {
        for (final entry in ratingTotals.entries)
          entry.key: entry.value / (ratingCounts[entry.key] ?? 1),
      };

      for (final value in acceptedBids) {
        final bid = Map<String, dynamic>.from(value as Map);
        final artisanId = (bid['artisan_id'] ?? '').toString();
        if (artisanId.isEmpty) continue;
        wonBidCounts.update(
          artisanId,
          (current) => current + 1,
          ifAbsent: () => 1,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Listing enrichment failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return rows
        .map((row) {
          final artisanId = (row['artisan_id'] ?? row['artisanId'])?.toString();
          final hydrated = Map<String, dynamic>.from(row);
          if (artisanId != null && artisanId.isNotEmpty) {
            hydrated['artisanName'] = artisanNames[artisanId] ?? '';
            hydrated['artisanPhotoUrl'] = artisanAvatars[artisanId] ?? '';
            hydrated['artisanBusy'] = artisanBusy[artisanId] ?? false;
            hydrated['verified_only'] = artisanVerified[artisanId] ?? false;
            hydrated['ratingAverage'] = ratingAverages[artisanId] ?? 0;
            hydrated['ratingCount'] = ratingCounts[artisanId] ?? 0;
            hydrated['wonBidCount'] = wonBidCounts[artisanId] ?? 0;
          }
          return Listing.fromJson(hydrated);
        })
        .toList(growable: false);
  }

  @override
  Future<List<Listing>> fetchListings() async {
    List<Listing> listings;
    try {
      final List<dynamic> response = await _supabase.rpc(
        'get_listing_feed',
        params: const {'p_limit': 100},
      );
      listings = response
          .map(
            (value) =>
                Listing.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
    } catch (error) {
      // Keep a rolling-deployment fallback while the database migration is
      // propagating. This path is still bounded and batch-hydrated.
      debugPrint('Optimized listing feed unavailable, using fallback: $error');
      final List<dynamic> response = await _supabase
          .from('listings')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      final rows = response
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false);
      listings = await _hydrateListings(rows);
    }
    await _localDb.cacheListings(listings);
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
    unawaited(_refresh());
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
    unawaited(_refresh());
    return hydrated.first;
  }

  @override
  Future<void> deleteListing(String listingId) async {
    await _supabase.from('listings').delete().eq('id', listingId);
    final next = _latest.where((item) => item.id != listingId).toList();
    await _localDb.cacheListings(next);
    _emit(next, force: true);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
