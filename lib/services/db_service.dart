import 'package:drift/drift.dart';
import '../models/listing.dart';

class LocalDbService {
  LocalDbService({QueryExecutor? executor}) : _executor = executor;

  final QueryExecutor? _executor;
  final List<Listing> _cachedListings = [];

  Future<void> cacheListings(List<Listing> listings) async {
    _cachedListings
      ..clear()
      ..addAll(listings);
  }

  Future<List<Listing>> loadCachedListings() async {
    return List<Listing>.from(_cachedListings);
  }

  QueryExecutor? get executor => _executor;
}
