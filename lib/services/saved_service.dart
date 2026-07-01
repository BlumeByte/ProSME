import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_service.dart';

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
// Mock implementation (used in MOCK_MODE or when Supabase is unavailable)
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
  SupabaseSavedService(this._supabase, [this._localDb]);

  final SupabaseClient _supabase;
  final LocalDbService? _localDb;

  @override
  Stream<List<String>> watchSavedListingIds(String userId) {
    late final StreamController<List<String>> controller;
    Timer? refreshTimer;
    var lastEmitted = const <String>[];

    void emitIfChanged(List<String> ids) {
      final next = List<String>.unmodifiable(ids);
      if (listEquals(lastEmitted, next)) return;
      lastEmitted = next;
      if (!controller.isClosed) controller.add(next);
    }

    Future<void> refresh() async {
      try {
        emitIfChanged(await fetchSavedListingIds(userId));
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh saved listings: $error');
        debugPrintStack(stackTrace: stackTrace);
        emitIfChanged(
          await _localDb?.loadCachedSavedListingIds(userId) ?? const [],
        );
      }
    }

    controller = StreamController<List<String>>.broadcast(
      onListen: () async {
        emitIfChanged(
          await _localDb?.loadCachedSavedListingIds(userId) ?? const [],
        );
        unawaited(refresh());
        refreshTimer = Timer.periodic(
          const Duration(seconds: 12),
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
  Future<List<String>> fetchSavedListingIds(String userId) async {
    await _syncPendingSavedListingActions(userId);
    final List<dynamic> rows = await _supabase
        .from('saved_listings')
        .select('listing_id')
        .eq('user_id', userId);
    final ids = rows
        .map((r) => (r as Map<String, dynamic>)['listing_id'] as String)
        .toList();
    await _localDb?.cacheSavedListingIds(userId, ids);
    return ids;
  }

  @override
  Future<void> saveListing(String userId, String listingId) async {
    await _localDb?.addCachedSavedListingId(userId, listingId);
    try {
      await _supabase.from('saved_listings').upsert({
        'user_id': userId,
        'listing_id': listingId,
      });
    } catch (error, stackTrace) {
      debugPrint('Saved listing will sync on next refresh: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _localDb?.addPendingSavedListingAction(
        userId: userId,
        listingId: listingId,
        action: 'save',
      );
    }
  }

  @override
  Future<void> unsaveListing(String userId, String listingId) async {
    await _localDb?.removeCachedSavedListingId(userId, listingId);
    try {
      await _supabase
          .from('saved_listings')
          .delete()
          .eq('user_id', userId)
          .eq('listing_id', listingId);
    } catch (error, stackTrace) {
      debugPrint('Saved listing removal will retry on next refresh: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _localDb?.addPendingSavedListingAction(
        userId: userId,
        listingId: listingId,
        action: 'unsave',
      );
    }
  }

  Future<void> _syncPendingSavedListingActions(String userId) async {
    final pending =
        await _localDb?.loadPendingSavedListingActions() ?? const [];
    for (final row in pending.where((row) => row['user_id'] == userId)) {
      final id = (row['id'] ?? '').toString();
      final listingId = (row['listing_id'] ?? '').toString();
      final action = (row['action'] ?? '').toString();
      if (id.isEmpty || listingId.isEmpty) continue;
      try {
        if (action == 'save') {
          await _supabase.from('saved_listings').upsert({
            'user_id': userId,
            'listing_id': listingId,
          });
        } else if (action == 'unsave') {
          await _supabase
              .from('saved_listings')
              .delete()
              .eq('user_id', userId)
              .eq('listing_id', listingId);
        }
        await _localDb?.removePendingSavedListingAction(id);
      } catch (_) {
        return;
      }
    }
  }
}
