import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'listing_service.dart';
import 'payment_service.dart';
import 'admin_service.dart';
import 'db_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (kDevMode) {
    return MockAuthService();
  }
  return FirebaseAuthService(firebase_auth.FirebaseAuth.instance);
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final listingServiceProvider = Provider<ListingService>((ref) {
  if (kDevMode) {
    return MockListingService();
  }
  return FirestoreListingService(FirebaseFirestore.instance);
});

final chatServiceProvider = Provider<ChatService>((ref) {
  if (kDevMode) {
    return MockChatService();
  }
  return FirestoreChatService(FirebaseFirestore.instance);
});

final paymentServiceProvider = Provider((ref) => PaymentService());

final adminServiceProvider = Provider((ref) => AdminService());

final localDbProvider = Provider((ref) => LocalDbService());
