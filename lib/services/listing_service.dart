import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class FirestoreListingService implements ListingService {
  FirestoreListingService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Listing>> watchListings() {
    return _firestore.collection('listings').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Listing.fromJson(doc.data()))
              .toList(),
        );
  }

  @override
  Future<List<Listing>> fetchListings() async {
    final snapshot = await _firestore.collection('listings').get();
    return snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
  }
}

ListingService buildListingService(FirebaseFirestore firestore) {
  return kDevMode ? MockListingService() : FirestoreListingService(firestore);
}
