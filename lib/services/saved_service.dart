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
  final _controller = StreamController<List<String>>.broadcast();

  @override
  Stream<List<String>> watchSavedListingIds(String userId) async* {
    yield List<String>.from(_saved);
    yield* _controller.stream;
  }

  @override
  Future<List<String>> fetchSavedListingIds(String userId) async {
    return List<String>.from(_saved);
  }

  @override
  Future<void> saveListing(String userId, String listingId) async {
    _saved.add(listingId);
    _controller.add(List<String>.from(_saved));
  }

  @override
  Future<void> unsaveListing(String userId, String listingId) async {
    _saved.remove(listingId);
    _controller.add(List<String>.from(_saved));
  }
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseSavedService implements SavedService {
  SupabaseSavedService(this._supabase, [this._localDb]);

  final SupabaseClient _supabase;
  final LocalDbService? _localDb;
  final Map<String, StreamController<List<String>>> _controllers = {};
  final Map<String, List<String>> _latestByUser = {};
  final Set<String> _startedUsers = {};

  @override
  Stream<List<String>> watchSavedListingIds(String userId) {
    _ensureUserStarted(userId);
    return Stream<List<String>>.multi((controller) {
      controller.add(
        List<String>.unmodifiable(_latestByUser[userId] ?? const []),
      );
      final subscription = _controllerFor(userId).stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  StreamController<List<String>> _controllerFor(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<String>>.broadcast(),
    );
  }

  void _ensureUserStarted(String userId) {
    if (!_startedUsers.add(userId)) return;
    unawaited(() async {
      final cached =
          await _localDb?.loadCachedSavedListingIds(userId) ?? const [];
      _emitSavedIds(userId, cached, force: true);
      await _refreshSavedIds(userId);
    }());
  }

  Future<void> _refreshSavedIds(String userId) async {
    try {
      _emitSavedIds(userId, await fetchSavedListingIds(userId));
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh saved listings: $error');
      debugPrintStack(stackTrace: stackTrace);
      _emitSavedIds(
        userId,
        await _localDb?.loadCachedSavedListingIds(userId) ?? const [],
        force: true,
      );
    }
  }

  void _emitSavedIds(String userId, List<String> ids, {bool force = false}) {
    final next = List<String>.unmodifiable(ids);
    final current = _latestByUser[userId] ?? const <String>[];
    if (!force && listEquals(current, next)) return;
    _latestByUser[userId] = next;
    final controller = _controllerFor(userId);
    if (!controller.isClosed) controller.add(next);
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
    final local =
        await _localDb?.loadCachedSavedListingIds(userId) ??
        {...?_latestByUser[userId], listingId}.toList();
    _emitSavedIds(userId, local, force: true);
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
    final local =
        await _localDb?.loadCachedSavedListingIds(userId) ??
        (_latestByUser[userId] ?? const <String>[])
            .where((id) => id != listingId)
            .toList();
    _emitSavedIds(userId, local, force: true);
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
