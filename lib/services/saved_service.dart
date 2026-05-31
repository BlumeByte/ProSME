import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';
import 'listing_service.dart';

abstract class SavedService {
  /// Emits the list of listing IDs saved by [userId] whenever it changes.
  Stream<List<String>> watchSavedListingIds(String userId);

  /// Returns the listing IDs currently saved by [userId].
  Future<List<String>> fetchSavedListingIds(String userId);

  /// Saves [listingId] for [userId]. No-op if already saved.
  Future<void> saveListing(String userId, String listingId);

  /// Removes the saved bookmark for [listingId] by [userId].
  Future<void> unsaveListing(String userId, String listingId);
}

// ---------------------------------------------------------------------------
// Mock implementation (used in DEV_MODE or when Supabase is unavailable)
// ---------------------------------------------------------------------------

class MockSavedService implements SavedService {
  final _saved = <String>{};

  @override
  Stream<List<String>> watchSavedListingIds(String userId) {
    return Stream.value(List<String>.from(_saved));
  }

  @override
  Future<List<String>> fetchSavedListingIds(String userId) async {
    return List<String>.from(_saved);
  }

  @override
  Future<void> saveListing(String userId, String listingId) async {
    _saved.add(listingId);
  }

  @override
  Future<void> unsaveListing(String userId, String listingId) async {
    _saved.remove(listingId);
  }
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseSavedService implements SavedService {
  SupabaseSavedService(this._supabase, this._listingService);

  final SupabaseClient _supabase;
  final ListingService _listingService;

  @override
  Stream<List<String>> watchSavedListingIds(String userId) {
    return _supabase
        .from('saved_listings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((r) => r['listing_id'] as String).toList());
  }

  @override
  Future<List<String>> fetchSavedListingIds(String userId) async {
    final List<dynamic> rows = await _supabase
        .from('saved_listings')
        .select('listing_id')
        .eq('user_id', userId);
    return rows.map((r) => (r as Map<String, dynamic>)['listing_id'] as String).toList();
  }

  /// Fetches the full [Listing] objects for all of [userId]'s saved listings.
  Future<List<Listing>> fetchSavedListings(String userId) async {
    final ids = await fetchSavedListingIds(userId);
    if (ids.isEmpty) return [];
    try {
      final all = await _listingService.fetchListings();
      return all.where((l) => ids.contains(l.id)).toList();
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch saved listings: $error');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Future<void> saveListing(String userId, String listingId) async {
    await _supabase.from('saved_listings').upsert({
      'user_id': userId,
      'listing_id': listingId,
    });
  }

  @override
  Future<void> unsaveListing(String userId, String listingId) async {
    await _supabase
        .from('saved_listings')
        .delete()
        .eq('user_id', userId)
        .eq('listing_id', listingId);
  }
}
