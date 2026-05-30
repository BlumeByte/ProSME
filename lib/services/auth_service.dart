import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../core/utils/mock_data.dart';
import '../models/app_user.dart';

abstract class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(String email, String password);
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithPhone(String phone);
  Future<void> signOut();
  Future<void> updateRole(UserRole role);
}

class MockAuthService implements AuthService {
  MockAuthService();

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    _currentUser = demoUser.copyWith(email: email, name: 'Demo User');
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password) async {
    _currentUser = demoUser.copyWith(email: email, name: 'New User');
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
    final roleName = user.userMetadata?['role'] as String?;
    return AppUser(
      id: user.id,
      role: UserRole.values.firstWhere(
        (role) => role.name == roleName,
        orElse: () => UserRole.customer,
      ),
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
  Future<AppUser> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': email.split('@').first,
      },
    );

    final user = response.user ?? _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign-up succeeded but no user session was returned.');
    }
    return _mapUser(user)!;
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
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {'role': role.name},
      ),
    );
  }
}
