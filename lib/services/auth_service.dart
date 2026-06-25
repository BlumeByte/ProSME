import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/app_user.dart';
import '../routes/route_names.dart';

final _emailRegex = RegExp(
  r'^(?=.{1,254}$)(?=.{1,64}@)[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
);
final _strongPasswordRegex = RegExp(
  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
);

bool _isValidEmailAddress(String email) =>
    _emailRegex.hasMatch(email) && !email.contains('..');
bool isStrongPassword(String password) =>
    _strongPasswordRegex.hasMatch(password);
String _readableError(Object? error) {
  if (error == null) return 'unknown error';
  if (error is AuthException) return error.message;
  return error.toString().replaceFirst(
        RegExp(r'^(StateError|FunctionException):\s*'),
        '',
      );
}

String limitProfileDescription(String description) {
  final normalized = description.trim();
  if (normalized.length <= 50) return normalized;
  return normalized.substring(0, 50);
}

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
  Future<void> verifyEmailOtp(String code);
  Future<void> requestPhoneOtp();
  Future<void> verifyPhoneOtp(String code);
  Future<void> updatePassword(String password, String emailOtp);
  Future<void> signOut();
  Future<void> updateRole(UserRole role);
  Future<void> updateUsername(String username, {String? emailOtp});
  Future<void> updateFullName(String fullName);
  Future<void> updatePhone(String phone);
  Future<void> updatePhoneAndCountry({
    required String phone,
    required String country,
    required String countryCode,
  });
  Future<void> updateCountry(String country, String countryCode);
  Future<void> updatePhoto(Uint8List bytes, {required String contentType});
  Future<void> updateDescription(String description);
  Future<void> updateAvailability({required bool isBusy});
  Future<void> updateEmail(String email);
  Future<void> deleteAccount({String? reason});
}

class PendingEmailVerificationException implements Exception {
  const PendingEmailVerificationException();
}

class MockAuthService implements AuthService {
  MockAuthService();

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  final Map<String, AppUser> _accountsByEmail = {};
  final Map<String, String> _passwordsByEmail = {};
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
    final account = _accountsByEmail[normalizedEmail];
    if (account == null || _passwordsByEmail[normalizedEmail] != password) {
      throw StateError('Invalid email or password.');
    }
    _currentUser = account;
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
    if (!isStrongPassword(password)) {
      throw StateError(
        'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
      );
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
      fullName: username.trim(),
      phone: '',
      email: email.trim(),
      photoUrl: '',
      verificationStatus: VerificationStatus.pending,
      createdAt: DateTime.now(),
    );
    _accountsByEmail[normalizedEmail] = _currentUser!;
    _passwordsByEmail[normalizedEmail] = password;
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
      fullName: 'Google User',
      phone: '',
      email: email,
      photoUrl: '',
      verificationStatus: VerificationStatus.pending,
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
  Future<void> verifyEmailOtp(String code) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    if (code.trim().length < 4) throw StateError('Enter the code sent to you.');
    _currentUser = _currentUser!.copyWith(emailVerified: true);
    _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> requestPhoneOtp() async {}

  @override
  Future<void> verifyPhoneOtp(String code) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    if (code.trim().length < 4) throw StateError('Enter the code sent to you.');
    _currentUser = _currentUser!.copyWith(phoneVerified: true);
    _accountsByEmail[_currentUser!.email.toLowerCase()] = _currentUser!;
    _controller.add(_currentUser);
  }

  @override
  Future<void> updatePassword(String password, String emailOtp) async {
    if (!isStrongPassword(password)) {
      throw StateError(
        'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
      );
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
  Future<void> updateFullName(String fullName) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = fullName.trim();
    if (normalized.isEmpty) {
      throw StateError('Full name cannot be empty.');
    }
    _currentUser = user.copyWith(fullName: normalized);
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
  Future<void> updatePhoneAndCountry({
    required String phone,
    required String country,
    required String countryCode,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      throw StateError('Phone cannot be empty.');
    }
    _currentUser = user.copyWith(
      phone: normalized,
      country: country,
      countryCode: countryCode,
    );
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
  Future<void> updateAvailability({required bool isBusy}) async {
    if (_currentUser == null) {
      throw StateError('No signed-in user.');
    }
    _currentUser = _currentUser!.copyWith(isBusy: isBusy);
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

    final previousPassword = _passwordsByEmail.remove(user.email.toLowerCase());
    _accountsByEmail.remove(user.email.toLowerCase());
    _emailByUsername[user.name.toLowerCase()] = normalized;
    _currentUser = user.copyWith(email: normalized);
    _accountsByEmail[normalized] = _currentUser!;
    if (previousPassword != null) {
      _passwordsByEmail[normalized] = previousPassword;
    }
    _controller.add(_currentUser);
  }

  @override
  Future<void> deleteAccount({String? reason}) async {
    final user = _currentUser;
    if (user != null) {
      _accountsByEmail.remove(user.email.toLowerCase());
      _passwordsByEmail.remove(user.email.toLowerCase());
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
  final StreamController<AppUser?> _profileController =
      StreamController<AppUser?>.broadcast();

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
            'id,username,full_name,phone,email,avatar_url,role,verification_status,country,country_code,description,is_busy,email_verified,phone_verified,email_notifications,phone_notifications,app_language,currency_code,username_updated_at,created_at,updated_at',
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
    final fullName = (existingProfile?['full_name'] ??
            metadata['full_name'] ??
            metadata['name'] ??
            _defaultDisplayName)
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
      // Settings phone numbers live in profiles. Auth phone can be empty when
      // the account uses email or Google sign-in, so never overwrite the
      // saved profile value during an auth refresh.
      'phone': existingProfile?['phone'] ?? user.phone ?? '',
      'avatar_url': avatarUrl,
      'country': existingProfile?['country'] ?? 'Ghana',
      'country_code': existingProfile?['country_code'] ?? '+233',
      'description': existingProfile?['description'] ?? '',
      'is_busy': existingProfile?['is_busy'] ?? false,
      'email_verified':
          existingProfile?['email_verified'] ?? (user.emailConfirmedAt != null),
      'phone_verified': existingProfile?['phone_verified'] ?? false,
      'role': role,
      'verification_status': (existingProfile?['verification_status'] ??
              VerificationStatus.pending.name)
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
      final updated = await _supabase
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError(
          'Profile update was not saved. Please sign in again and retry.',
        );
      }
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
      fullName: (source['full_name'] ??
              metadata['full_name'] ??
              metadata['name'] ??
              '')
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
      isBusy: source['is_busy'] == true ||
          source['isBusy'] == true ||
          metadata['is_busy'] == true ||
          metadata['isBusy'] == true,
      emailVerified: source['email_verified'] == true ||
          source['emailVerified'] == true ||
          metadata['email_verified'] == true ||
          user.emailConfirmedAt != null,
      phoneVerified: source['phone_verified'] == true ||
          source['phoneVerified'] == true ||
          metadata['phone_verified'] == true,
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) =>
            status.name ==
            (source['verification_status'] ??
                    source['verificationStatus'] ??
                    metadata['verification_status'] ??
                    metadata['verificationStatus'] ??
                    VerificationStatus.pending.name)
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
    final controller = StreamController<AppUser?>();
    Future<void> emitInitial() async {
      final currentUser = _supabase.auth.currentUser;
      controller
          .add(currentUser == null ? null : await _resolveUser(currentUser));
    }

    unawaited(emitInitial());
    final authSub = _supabase.auth.onAuthStateChange.listen((authState) async {
      final user = authState.session?.user ?? _supabase.auth.currentUser;
      if (user == null) {
        _resolvedCurrentUser = null;
        controller.add(null);
        return;
      }
      controller.add(await _resolveUser(user));
    });
    final profileSub = _profileController.stream.listen(controller.add);
    controller.onCancel = () async {
      await authSub.cancel();
      await profileSub.cancel();
    };
    yield* controller.stream;
  }

  @override
  AppUser? get currentUser =>
      _resolvedCurrentUser ?? _mapUser(_supabase.auth.currentUser);

  void _emitProfileUpdate() {
    _profileController.add(_resolvedCurrentUser);
  }

  Future<void> _syncAuthMetadata(Map<String, dynamic> data) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(data: data));
    } catch (error) {
      debugPrint('Optional auth metadata sync failed: $error');
    }
  }

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
    if (!isStrongPassword(password)) {
      throw StateError(
        'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
      );
    }
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: kIsWeb ? null : kEmailVerificationRedirectUrl,
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
    final redirectTo = kIsWeb
        ? Uri.base.resolve(RouteNames.resetPassword).toString()
        : kPasswordRecoveryRedirectUrl;
    Object? functionError;
    try {
      final response = await _supabase.functions.invoke(
        'password-recovery',
        body: {'email': normalized, 'redirectTo': redirectTo},
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) return;
      functionError = StateError(
        data is Map
            ? (data['error'] ?? 'Password recovery service failed.').toString()
            : 'Password recovery service returned an invalid response.',
      );
    } catch (error) {
      functionError = error;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        normalized,
        redirectTo: redirectTo,
      );
    } catch (authError) {
      throw StateError(
        'The reset email could not be sent. Recovery service: '
        '${_readableError(functionError)}. Supabase Auth: ${_readableError(authError)}',
      );
    }
  }

  @override
  Future<void> requestEmailOtp() async {
    await _invokeVerification('requestEmailCode');
  }

  @override
  Future<void> verifyEmailOtp(String code) async {
    await _invokeVerification('verifyEmailCode', code: code);
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        emailVerified: true,
      );
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> requestPhoneOtp() async {
    await _invokeVerification('requestPhoneCode');
  }

  @override
  Future<void> verifyPhoneOtp(String code) async {
    await _invokeVerification('verifyPhoneCode', code: code);
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        phoneVerified: true,
      );
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> updatePassword(String password, String emailOtp) async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('No signed-in user.');
    }
    if (!isStrongPassword(password)) {
      throw StateError(
        'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
      );
    }

    await _supabase.auth.updateUser(
      UserAttributes(password: password),
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
          'verification_status': VerificationStatus.pending.name,
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
        _emitProfileUpdate();
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
    await _updateProfile(user.id, {
      'username': normalized,
      'username_updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    unawaited(_syncAuthMetadata({'username': normalized}));

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(name: normalized);
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> updateFullName(String fullName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = fullName.trim();
    if (normalized.isEmpty) {
      throw StateError('Full name cannot be empty.');
    }

    await _updateProfile(user.id, {'full_name': normalized});
    unawaited(_syncAuthMetadata({'full_name': normalized, 'name': normalized}));

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser =
          _resolvedCurrentUser!.copyWith(fullName: normalized);
      _emitProfileUpdate();
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

    await _updateProfile(user.id, {
      'phone': normalized,
    });

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        phone: normalized,
      );
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> updatePhoneAndCountry({
    required String phone,
    required String country,
    required String countryCode,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      throw StateError('Phone cannot be empty.');
    }

    await _updateProfile(user.id, {
      'phone': normalized,
      'country': country,
      'country_code': countryCode,
    });

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        phone: normalized,
        country: country,
        countryCode: countryCode,
      );
      _emitProfileUpdate();
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
      _emitProfileUpdate();
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
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> updateDescription(String description) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    final normalized = limitProfileDescription(description);
    await _updateProfile(user.id, {'description': normalized});
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser =
          _resolvedCurrentUser!.copyWith(description: normalized);
      _emitProfileUpdate();
    }
  }

  @override
  Future<void> updateAvailability({required bool isBusy}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    await _updateProfile(user.id, {'is_busy': isBusy});
    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(isBusy: isBusy);
      _emitProfileUpdate();
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

    await _updateProfile(user.id, {
      'email': normalized,
      'email_verified': false,
    });
    await _supabase.auth.updateUser(
      UserAttributes(
        email: normalized,
        data: {'email': normalized},
      ),
    );

    if (_resolvedCurrentUser != null) {
      _resolvedCurrentUser = _resolvedCurrentUser!.copyWith(
        email: normalized,
        emailVerified: false,
      );
      _emitProfileUpdate();
    }
  }

  Future<void> _invokeVerification(String action, {String? code}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    final response = await _supabase.functions.invoke(
      'account-verification',
      body: {
        'action': action,
        if (code != null) 'code': code.trim(),
      },
    );
    final data = response.data;
    final payload = data is Map ? Map<String, dynamic>.from(data) : {};
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        (payload['error'] ?? 'Verification request failed.').toString(),
      );
    }
    if (payload['ok'] != true) {
      throw StateError(
        (payload['error'] ?? 'Verification request failed.').toString(),
      );
    }
  }

  @override
  Future<void> deleteAccount({String? reason}) async {
    final user = _supabase.auth.currentUser;
    final normalizedReason = (reason ?? '').trim();
    if (user != null && normalizedReason.isNotEmpty) {
      try {
        await _supabase.from('admin_notifications').insert({
          'type': 'account_deletion',
          'title': 'Account deletion requested',
          'body': normalizedReason,
          'actor_id': user.id,
          'related_user_id': user.id,
        });
      } catch (_) {
        // Account deletion should not be blocked by support-log failures.
      }
    }
    await _supabase.rpc('delete_current_user');
    _resolvedCurrentUser = null;
  }
}
