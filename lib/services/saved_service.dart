import 'package:supabase_flutter/supabase_flutter.dart';

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
  SupabaseSavedService(this._supabase);

  final SupabaseClient _supabase;

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
    return rows
        .map((r) => (r as Map<String, dynamic>)['listing_id'] as String)
        .toList();
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
