import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing.dart';

class SyncService {
  SyncService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<Listing>> listenListings() {
    return _firestore.collection('listings').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Listing.fromJson(doc.data()))
              .toList(),
        );
  }
}
