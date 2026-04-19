import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._supabase);

  final SupabaseClient _supabase;

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      role: UserRole.customer,
      name: user.userMetadata?['full_name'] as String? ?? 'User',
      phone: user.phone ?? '',
      email: user.email ?? '',
      photoUrl: user.userMetadata?['avatar_url'] as String? ?? '',
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _supabase.auth.onAuthStateChange.map(
      (authState) => _mapUser(authState.session?.user),
    );
  }

  @override
  AppUser? get currentUser => _mapUser(_supabase.auth.currentUser);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _mapUser(response.user)!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(OAuthProvider.google);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Google sign-in did not return a user session.');
    }
    return _mapUser(user)!;
  }

  @override
  Future<AppUser> signInWithPhone(String phone) async {
    throw UnimplementedError('Phone OTP should be implemented with Supabase.');
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> updateRole(UserRole role) async {
    // TODO: Persist role in Supabase profiles table.
  }
}

/// [AuthService] implementation backed by Supabase Auth.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final sb.SupabaseClient _client;

  AppUser? _mapUser(sb.User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? {};
    return AppUser(
      id: user.id,
      role: UserRole.values.firstWhere(
        (r) => r.name == (meta['role'] as String?),
        orElse: () => UserRole.customer,
      ),
      name: (meta['full_name'] as String?) ?? user.email ?? 'User',
      phone: user.phone ?? '',
      email: user.email ?? '',
      photoUrl: (meta['avatar_url'] as String?) ?? '',
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => _mapUser(event.session?.user));
  }

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw Exception('Sign-in failed: no user returned from Supabase.');
    }
    return _mapUser(user)!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    // Supabase OAuth launches a browser and returns via a deep link.
    // The authenticated user is delivered through [authStateChanges] once the
    // redirect completes. Callers should listen to that stream instead of
    // awaiting this method's return value.
    await _client.auth.signInWithOAuth(sb.OAuthProvider.google);
    throw UnimplementedError(
      'Google sign-in uses a browser redirect. '
      'Listen to authStateChanges() for the authenticated user.',
    );
  }

  @override
  Future<AppUser> signInWithPhone(String phone) async {
    // Step 1: send OTP. Step 2: call verifyPhoneOtp() with the received token.
    await _client.auth.signInWithOtp(phone: phone);
    throw UnimplementedError(
      'Phone sign-in is a two-step process. '
      'After receiving the OTP, call verifyPhoneOtp() to complete sign-in.',
    );
  }

  /// Verifies the OTP received via SMS and returns the signed-in user.
  Future<AppUser> verifyPhoneOtp(String phone, String token) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: sb.OtpType.sms,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('OTP verification failed: no user returned from Supabase.');
    }
    return _mapUser(user)!;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> updateRole(UserRole role) async {
    await _client.auth.updateUser(
      sb.UserAttributes(data: {'role': role.name}),
    );
  }
}
