import 'dart:async';
import 'package:flutter/foundation.dart';
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
  AppUser? _resolvedCurrentUser;

  bool _isMissingProfilesTable(Object error) {
    if (error is! PostgrestException) return false;
    if (error.code == '42P01') return true;
    final details = '${error.message} ${error.details}'.toLowerCase();
    return details.contains('profiles') && details.contains('does not exist');
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id,full_name,name,phone,email,avatar_url,role,created_at')
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (error) {
      if (_isMissingProfilesTable(error)) return null;
      rethrow;
    }
  }

  Future<void> _upsertProfile(User user) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final fullName = (metadata['full_name'] ?? metadata['name'] ?? 'New User')
        .toString();
    final avatarUrl = (metadata['avatar_url'] ?? '').toString();
    final role = (metadata['role'] ?? UserRole.customer.name).toString();

    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'email': user.email ?? '',
        'phone': user.phone ?? '',
        'avatar_url': avatarUrl,
        'role': role,
      }, onConflict: 'id');
    } catch (error) {
      if (_isMissingProfilesTable(error)) return;
      rethrow;
    }
  }

  AppUser? _mapUser(User? user, {Map<String, dynamic>? profile}) {
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final source = profile ?? metadata;
    final roleName = (source['role'] ?? metadata['role']) as String?;
    return AppUser(
      id: user.id,
      role: UserRole.values.firstWhere(
        (role) => role.name == roleName,
        orElse: () => UserRole.customer,
      ),
      name: (source['full_name'] ??
                  source['name'] ??
                  metadata['full_name'] ??
                  metadata['name'] ??
                  'New User')
              .toString(),
      phone: (source['phone'] ?? user.phone ?? '').toString(),
      email: (source['email'] ?? user.email ?? '').toString(),
      photoUrl:
          (source['avatar_url'] ?? metadata['avatar_url'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (source['created_at'] ?? user.createdAt).toString(),
          ) ??
          DateTime.now(),
    );
  }

  Future<AppUser> _resolveUser(User user) async {
    try {
      await _upsertProfile(user);
      final profile = await _fetchProfile(user.id);
      final mappedUser = _mapUser(user, profile: profile)!;
      _resolvedCurrentUser = mappedUser;
      return mappedUser;
    } catch (error, stackTrace) {
      debugPrint('Failed to resolve Supabase profile: $error');
      debugPrintStack(stackTrace: stackTrace);
      final mappedUser = _mapUser(user)!;
      _resolvedCurrentUser = mappedUser;
      return mappedUser;
    }
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user == null) {
        _resolvedCurrentUser = null;
        return null;
      }
      return _resolveUser(user);
    });
  }

  @override
  AppUser? get currentUser =>
      _resolvedCurrentUser ?? _mapUser(_supabase.auth.currentUser);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user ?? _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign-in completed but no active session was returned.');
    }
    return _resolveUser(user);
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': 'New User',
      },
    );

    final user = response.user ?? _supabase.auth.currentUser;
    if (user == null) {
      throw StateError(
        'Sign-up completed but no active session was returned. Please sign in.',
      );
    }
    return _resolveUser(user);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(OAuthProvider.google);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Google sign-in did not return a user session.');
    }
    return _resolveUser(user);
  }

  @override
  Future<AppUser> signInWithPhone(String phone) async {
    throw UnimplementedError('Phone OTP should be implemented with Supabase.');
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _resolvedCurrentUser = null;
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
