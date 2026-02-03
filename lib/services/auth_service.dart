import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/constants.dart';
import '../core/utils/mock_data.dart';
import '../models/app_user.dart';

abstract class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithPhone(String phone);
  Future<void> signOut();
  Future<void> updateRole(UserRole role);
}

class MockAuthService implements AuthService {
  MockAuthService() {
    _controller.add(null);
  }

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    _currentUser = demoUser.copyWith(email: email, name: 'Demo User');
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    _currentUser = demoUser;
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithPhone(String phone) async {
    _currentUser = demoUser.copyWith(phone: phone, name: 'Phone User');
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> updateRole(UserRole role) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(role: role);
      _controller.add(_currentUser);
    }
  }
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._firebaseAuth);

  final firebase_auth.FirebaseAuth _firebaseAuth;

  AppUser? _mapUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      role: UserRole.customer,
      name: user.displayName ?? 'User',
      phone: user.phoneNumber ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapUser(credential.user)!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    final googleAuth = await googleUser?.authentication;
    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return _mapUser(userCredential.user)!;
  }

  @override
  Future<AppUser> signInWithPhone(String phone) async {
    throw UnimplementedError('Phone OTP should be implemented with Firebase.');
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> updateRole(UserRole role) async {
    // TODO: Persist role in Firestore user profile.
  }
}
