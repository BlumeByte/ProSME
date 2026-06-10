import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/app_user.dart';

final _emailRegex = RegExp(
  r'^(?=.{1,254}$)(?=.{1,64}@)[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
);

bool _isValidEmailAddress(String email) =>
    _emailRegex.hasMatch(email) && !email.contains('..');

abstract class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(
    String email,
    String password, {
    String? username,
    UserRole role = UserRole.customer,
  });
  Future<AppUser> signInWithGoogle();
  Future<void> requestPasswordReset(String email);
  Future<void> requestEmailOtp();
  Future<void> updatePassword(String password, String emailOtp);
  Future<void> signOut();
  Future<void> updateRole(UserRole role);
  Future<void> updateUsername(String username, {String? emailOtp});
  Future<void> updatePhone(String phone);
  Future<void> updateCountry(String country, String countryCode);
  Future<void> updatePhoto(Uint8List bytes, {required String contentType});
  Future<void> updateDescription(String description);
  Future<void> updateEmail(String email);
  Future<void> deleteAccount();
}

class PendingEmailVerificationException implements Exception {
  const PendingEmailVerificationException();
}

class MockAuthService implements AuthService {
  MockAuthService();

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  final Map<String, AppUser> _accountsByEmail = {};
  final Map<String, String> _emailByUsername = {};
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
    final normalizedEmail = email.trim().toLowerCase();
    _currentUser = _accountsByEmail[normalizedEmail] ??
        AppUser(
          id: 'mock_${DateTime.now().microsecondsSinceEpoch}',
          role: UserRole.customer,
          name: normalizedEmail.split('@').first,
          phone: '',
          email: normalizedEmail,
          photoUrl: '',
          verificationStatus: VerificationStatus.verified,
          createdAt: DateTime.now(),
        );
    _accountsByEmail[normalizedEmail] = _currentUser!;
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signUpWithEmail(
    String email,
    String password, {
    String? username,
    UserRole role = UserRole.customer,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = (username ?? '').trim().toLowerCase();

    if (_accountsByEmail.containsKey(normalizedEmail)) {
      throw StateError('This email is already registered.');
    }
    if (normalizedUsername.isEmpty) {
      throw StateError('Please provide a username.');
    }
    if (_emailByUsername.containsKey(normalizedUsername)) {
      throw StateError('That username is already taken.');
    }

    _currentUser = AppUser(
      id: 'mock_${DateTime.now().microsecondsSinceEpoch}',
      role: role,
      name: username!.trim(),
      phone: '',
      email: email.trim(),
      photoUrl: '',
      verificationStatus: role == UserRole.artisan
          ? VerificationStatus.pending
          : VerificationStatus.verified,
      createdAt: DateTime.now(),
    );
    _accountsByEmail[normalizedEmail] = _currentUser!;
    _emailByUsername[normalizedUsername] = normalizedEmail;
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final email = 'google_user_$now@example.com';
    _currentUser = AppUser(
      id: 'mock_google_$now',
      role: UserRole.customer,
      name: 'Google User',
      phone: '',
      email: email,
      photoUrl: '',
      verificationStatus: VerificationStatus.verified,
      createdAt: DateTime.now(),
    );
    _accountsByEmail[email] = _currentUser!;
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> requestEmailOtp() async {}

  @override
  Future<void> updatePassword(String password, String emailOtp) async {
    if (password.length < 6) {
      throw StateError('Password must be at least 6 characters.');
    }
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
      _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
      _controller.add(_currentUser);
    }
  }

  @override
  Future<void> updateUsername(String username, {String? emailOtp}) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final nextUsername = username.trim();
    if (nextUsername.isEmpty) {
      throw StateError('Username cannot be empty.');
    }

    final normalizedNext = nextUsername.toLowerCase();
    final ownerEmail = _emailByUsername[normalizedNext];
    if (ownerEmail != null && ownerEmail != user.email.toLowerCase()) {
      throw StateError('That username is already taken.');
    }

    _emailByUsername.remove(user.name.toLowerCase());
    _emailByUsername[normalizedNext] = user.email.toLowerCase();
    _currentUser = user.copyWith(name: nextUsername);
    _accountsByEmail[user.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updatePhone(String phone) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      throw StateError('Phone cannot be empty.');
    }
    _currentUser = user.copyWith(phone: normalized);
    _accountsByEmail[user.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updateCountry(String country, String countryCode) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    _currentUser = _currentUser!.copyWith(
      country: country,
      countryCode: countryCode,
    );
    _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updatePhoto(Uint8List bytes,
      {required String contentType}) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    final dataUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
    _currentUser = _currentUser!.copyWith(photoUrl: dataUrl);
    _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updateDescription(String description) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    _currentUser = _currentUser!.copyWith(description: description.trim());
    _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updateEmail(String email) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmailAddress(normalized)) {
      throw StateError('Enter a valid email address.');
    }

    final existing = _accountsByEmail[normalized];
    if (existing != null && existing.id != user.id) {
      throw StateError('This email is already registered.');
    }

    _accountsByEmail.remove(user.email.toLowerCase());
    _emailByUsername[user.name.toLowerCase()] = normalized;
    _currentUser = user.copyWith(email: normalized);
    _accountsByEmail[normalized] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user != null) {
      _accountsByEmail.remove(user.email.toLowerCase());
      _emailByUsername.remove(user.name.toLowerCase());
    }
    _currentUser = null;
    _controller.add(null);
  }
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._supabase);

  final SupabaseClient _supabase;
  static const String _defaultDisplayName = 'New User';
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
          .select(
            'id,username,full_name,phone,email,avatar_url,role,verification_status,country,country_code,description,username_updated_at,created_at,updated_at',
          )
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
    final existingProfile = await _fetchProfile(user.id);
    final fullName =
        (metadata['full_name'] ?? metadata['name'] ?? _defaultDisplayName)
            .toString();
    final username = metadata['username']?.toString().trim();
    final metadataAvatarUrl = (metadata['avatar_url'] ?? '').toString();
    final existingAvatarUrl = (existingProfile?['avatar_url'] ?? '').toString();
    final avatarUrl =
        metadataAvatarUrl.isNotEmpty ? metadataAvatarUrl : existingAvatarUrl;
    final role =
        (existingProfile?['role'] ?? metadata['role'] ?? UserRole.customer.name)
            .toString();

    final payload = <String, dynamic>{
      'id': user.id,
      'full_name': fullName,
      'email': user.email ?? '',
      'phone': user.phone ?? '',
      'avatar_url': avatarUrl,
      'country': existingProfile?['country'] ?? 'Ghana',
      'country_code': existingProfile?['country_code'] ?? '+233',
      'description': existingProfile?['description'] ?? '',
      'role': role,
      'verification_status': (existingProfile?['verification_status'] ??
              (role == UserRole.artisan.name
                  ? VerificationStatus.pending.name
                  : VerificationStatus.verified.name))
          .toString(),
    };
    if (username != null && username.isNotEmpty) {
      payload['username'] = username;
    }

    try {
      await _supabase.from('profiles').upsert(payload, onConflict: 'id');
    } catch (error) {
      if (_isMissingProfilesTable(error)) return;
      rethrow;
    }
  }

  Future<void> _updateProfile(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase.from('profiles').update(payload).eq('id', userId);
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
      name: (source['username'] ??
              source['full_name'] ??
              source['name'] ??
              metadata['username'] ??
              metadata['full_name'] ??
              metadata['name'] ??
              _defaultDisplayName)
          .toString(),
      phone: (source['phone'] ?? user.phone ?? '').toString(),
      email: (source['email'] ?? user.email ?? '').toString(),
      photoUrl:
          (source['avatar_url'] ?? metadata['avatar_url'] ?? '').toString(),
      country: (source['country'] ?? metadata['country'] ?? 'Ghana').toString(),
      countryCode:
          (source['country_code'] ?? metadata['country_code'] ?? '+233')
              .toString(),
      description:
          (source['description'] ?? metadata['description'] ?? '').toString(),
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) =>
            status.name ==
            (source['verification_status'] ??
                    source['verificationStatus'] ??
                    metadata['verification_status'] ??
                    metadata['verificationStatus'] ??
                    (roleName == UserRole.artisan.name
                        ? VerificationStatus.pending.name
                        : VerificationStatus.verified.name))
                .toString(),
        orElse: () => VerificationStatus.pending,
      ),
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

  Future<AppUser> _waitForActiveUser({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final existingUser = _supabase.auth.currentUser;
    if (existingUser != null) {
      return _resolveUser(existingUser);
    }

    final completer = Completer<User>();
    late final StreamSubscription<AuthState> subscription;

    subscription = _supabase.auth.onAuthStateChange.listen((authState) {
      final user = authState.session?.user ?? _supabase.auth.currentUser;
      if (user != null && !completer.isCompleted) {
        completer.complete(user);
      }
    }, onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    });

    try {
      final user = await completer.future.timeout(timeout);
      return _resolveUser(user);
    } on TimeoutException {
      throw StateError(
        'Google sign-in timed out. Please complete the sign-in flow and return to the app.',
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      yield null;
    } else {
      yield await _resolveUser(currentUser);
    }

    yield* _supabase.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user ?? _supabase.auth.currentUser;
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
      email: email.trim(),
      password: password,
    );
    final user = response.user ?? _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign-in completed but no active session was returned.');
    }
    return _resolveUser(user);
  }

  @override
  Future<AppUser> signUpWithEmail(
    String email,
    String password, {
    String? username,
    UserRole role = UserRole.customer,
  }) async {
    final normalizedUsername = (username ?? email.split('@').first).trim();
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': normalizedUsername,
        'username': normalizedUsername,
        'role': role.name,
      },
    );

    if (response.session == null && _supabase.auth.currentUser == null) {
      throw const PendingEmailVerificationException();
    }

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
    final launched = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : kGoogleOAuthRedirectUrl,
    );
    if (!launched) {
      throw StateError(
        'Google sign-in could not open. Confirm Google provider and redirect URL are configured in Supabase.',
      );
    }
    return _waitForActiveUser();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmailAddress(normalized)) {
      throw StateError('Enter a valid email address.');
    }
    await _supabase.auth.resetPasswordForEmail(normalized);
  }

  @override
  Future<void> requestEmailOtp() async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('No signed-in user.');
    }
    await _supabase.auth.reauthenticate();
  }

  @override
  Future<void> updatePassword(String password, String emailOtp) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('No signed-in user.');
    }
    final normalizedOtp = emailOtp.trim();
    if (password.length < 6) {
      throw StateError('Password must be at least 6 characters.');
    }
    if (normalizedOtp.isEmpty) {
      throw StateError('Enter the email verification code.');
    }

    await _supabase.auth.updateUser(
      UserAttributes(password: password, nonce: normalizedOtp),
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _resolvedCurrentUser = null;
  }

  @override
  Future<void> updateRole(UserRole role) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final payload = <String, dynamic>{
          'id': user.id,
          'full_name': (user.userMetadata?['full_name'] ??
                  user.userMetadata?['username'] ??
                  user.userMetadata?['name'] ??
                  _defaultDisplayName)
              .toString(),
          'email': user.email ?? '',
          'phone': user.phone ?? '',
          'avatar_url': (user.userMetadata?['avatar_url'] ?? '').toString(),
          'role': role.name,
          'verification_status': role == UserRole.artisan
              ? VerificationStatus.pending.name
              : VerificationStatus.verified.name,
        };
        final username = user.userMetadata?['username']?.toString().trim();
        if (username != null && username.isNotEmpty) {
          payload['username'] = username;
        }
        await _supabase.from('profiles').upsert(payload, onConflict: 'id');
      } catch (error) {
        if (!_isMissingProfilesTable(error)) rethrow;
      }
      final mapped = _resolvedCurrentUser ?? _mapUser(user);
      if (mapped != null) {
        _resolvedCurrentUser = mapped.copyWith(role: role);
      }
    }

    await _supabase.auth.updateUser(
      UserAttributes(
        data: {'role': role.name},
      ),
    );
  }

  @override
  Future<void> updateUsername(String username, {String? emailOtp}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw StateError('Username cannot be empty.');
    }
    if ((emailOtp ?? '').trim().isEmpty) {
      throw StateError('Enter the email verification code.');
    }
    final profile = await _fetchProfile(user.id);
    final lastChangedRaw =
        (profile?['username_updated_at'] ?? profile?['updated_at'])
            ?.toString();
    final lastChanged = DateTime.tryParse(lastChangedRaw ?? '');
    if (lastChanged != null &&
        DateTime.now().toUtc().difference(lastChanged.toUtc()) <
            const Duration(days: 14)) {
      throw StateError('Username can only be changed once every 14 days.');
    }

    await _updateProfile(user.id, {
      'username': normalized,
      'full_name': normalized,
      'username_updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'username': normalized,
          'full_name': normalized,
          'name': normalized,
        },
        nonce: emailOtp!.trim(),
      ),
    );

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(name: normalized);
    }
  }

  @override
  Future<void> updatePhone(String phone) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      throw StateError('Phone cannot be empty.');
    }

    await _updateProfile(
        user.id, {'phone': normalized, 'phone_verified': false});

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(phone: normalized);
    }
  }

  @override
  Future<void> updateCountry(String country, String countryCode) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    await _updateProfile(user.id, {
      'country': country,
      'country_code': countryCode,
    });
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        country: country,
        countryCode: countryCode,
      );
    }
  }

  @override
  Future<void> updatePhoto(Uint8List bytes,
      {required String contentType}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final extension = contentType == 'image/png' ? 'png' : 'jpg';
    final path =
        '${user.id}/avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
    try {
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      throw StateError(
        'Storage bucket "avatars" is not ready or your account cannot upload to it. ${error.message}',
      );
    }
    final url = _supabase.storage.from('avatars').getPublicUrl(path);
    await _updateProfile(user.id, {'avatar_url': url});
    await _supabase.auth.updateUser(
      UserAttributes(data: {'avatar_url': url}),
    );
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(photoUrl: url);
    }
  }

  @override
  Future<void> updateDescription(String description) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = description.trim();
    await _updateProfile(user.id, {'description': normalized});
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser =
          _resolvedCurrentUser!.copyWith(description: normalized);
    }
  }

  @override
  Future<void> updateEmail(String email) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmailAddress(normalized)) {
      throw StateError('Enter a valid email address.');
    }

    await _updateProfile(user.id, {'email': normalized});
    await _supabase.auth.updateUser(
      UserAttributes(
        email: normalized,
        data: {'email': normalized},
      ),
    );

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(email: normalized);
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _supabase.rpc('delete_current_user');
    _resolvedCurrentUser = null;
  }
}
