import 'dart:async';
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

  @override
  Stream<List<Listing>> watchListings() {
    return _supabase
        .from('listings')
        .stream(primaryKey: ['id']).map(
          (rows) => rows.map((row) => Listing.fromJson(row)).toList(),
        );
  }

  @override
  Future<List<Listing>> fetchListings() async {
    final List<dynamic> response = await _supabase.from('listings').select();
    return response
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

ListingService buildListingService(SupabaseClient supabase) {
  return kDevMode ? MockListingService() : SupabaseListingService(supabase);
}
