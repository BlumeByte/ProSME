import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../core/utils/mock_data.dart';
import '../models/listing.dart';

abstract class ListingService {
  Stream<List<Listing>> watchListings();
  Future<List<Listing>> fetchListings();
}

class MockListingService implements ListingService {
  final StreamController<List<Listing>> _controller =
      StreamController<List<Listing>>.broadcast();

  MockListingService() {
    _controller.add(demoListings);
  }

  @override
  Stream<List<Listing>> watchListings() => _controller.stream;

  @override
  Future<List<Listing>> fetchListings() async => demoListings;
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
            .select('id,full_name,avatar_url')
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
    return _supabase
        .from('listings')
        .stream(primaryKey: ['id'])
        .asyncMap(
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
}

ListingService buildListingService(SupabaseClient supabase) {
  return kDevMode ? MockListingService() : SupabaseListingService(supabase);
}
