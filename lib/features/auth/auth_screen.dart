import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../models/app_user.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/auth_service.dart';
import '../../services/service_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCreateAccountMode = false;
  UserRole _selectedRole = UserRole.customer;

  String get _username => _usernameController.text.trim();
  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;

  String _friendlyError(Object error) {
    if (error is PendingEmailVerificationException) {
      return 'Account created. Click the verification link in your email, then sign in.';
    }
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('already registered')) {
      return 'This email is already registered. Please sign in.';
    }
    if (message.contains('email') &&
        message.contains('duplicate') &&
        message.contains('unique')) {
      return 'This email is already registered. Please sign in.';
    }
    if (message.contains('username') &&
        (message.contains('duplicate') ||
            message.contains('already') ||
            message.contains('unique'))) {
      return 'That username is already taken. Please choose another one.';
    }
    if (message.contains('verify your email')) {
      return 'Account created. Check your email to verify, then sign in.';
    }
    if (message.contains('google sign-in') ||
        message.contains('unsupported provider') ||
        message.contains('provider is not enabled') ||
        message.contains('redirect url') ||
        message.contains('oauth')) {
      return 'Google sign-in is not configured yet. Check Google sign-in and redirect settings.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _friendlyPasswordResetError(Object error) {
    final message = error is AuthException
        ? error.message
        : error.toString().replaceFirst(RegExp(r'^StateError:\s*'), '');
    final normalized = message.toLowerCase();
    if (normalized.contains('rate limit') || normalized.contains('too many')) {
      return 'Too many reset attempts. Please wait a few minutes and try again.';
    }
    if (normalized.contains('redirect')) {
      return 'Password reset redirect is not allowed in account settings.';
    }
    if (normalized.contains('smtp') || normalized.contains('email')) {
      return 'The reset email could not be sent. Check account email settings.';
    }
    return message;
  }

  Future<void> _showForgotPasswordDialog(AuthService authService) async {
    final settings = ref.read(appSettingsControllerProvider);
    final controller = TextEditingController(text: _email);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Reset password')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: settings.t('Email')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(settings.t('Send email')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await authService.requestPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t('Password reset email sent. Check your inbox.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t(_friendlyPasswordResetError(error))),
        ),
      );
    }
  }

  String? _validateEmailPassword() {
    if (_email.isEmpty || _password.isEmpty) {
      return 'Please enter email and password.';
    }
    if (!_emailPattern.hasMatch(_email)) {
      return 'Please enter a valid email.';
    }
    if (_isCreateAccountMode && !isStrongPassword(_password)) {
      return 'Password must be 8+ characters with uppercase, lowercase, number, and special character.';
    }
    return null;
  }

  String? _validateSignUp() {
    final baseValidation = _validateEmailPassword();
    if (baseValidation != null) return baseValidation;
    if (_username.isEmpty) {
      return 'Please enter a username.';
    }
    if (!_usernamePattern.hasMatch(_username)) {
      return 'Username must be 3-20 characters (letters, numbers, underscores).';
    }
    return null;
  }

  String _routeForUser(AppUser user) {
    switch (user.role) {
      case UserRole.artisan:
        return RouteNames.artisanHome;
      case UserRole.admin:
        return RouteNames.adminHome;
      case UserRole.customer:
        return RouteNames.home;
    }
  }

  Future<void> _signIn(
    Future<AppUser> Function() action, {
    bool forceRoleSelection = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      if (mounted) {
        if (forceRoleSelection) {
          context.go(RouteNames.role);
        } else if (user.role == UserRole.artisan && _isCreateAccountMode) {
          context.go(RouteNames.artisanVerification);
        } else {
          context.go(_routeForUser(user));
        }
      }
    } catch (error) {
      if (!mounted) return;
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t(_friendlyError(error)))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final title = _isCreateAccountMode ? 'Create account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t(title)),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : () => context.go(RouteNames.home),
            icon: const Icon(Icons.home_outlined),
            label: Text(settings.t('Home')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(settings.t('Sign in')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(settings.t('Create account')),
                ),
              ],
              selected: {_isCreateAccountMode},
              onSelectionChanged: _isLoading
                  ? null
                  : (selection) {
                      setState(() {
                        _isCreateAccountMode = selection.first;
                      });
                    },
            ),
            const SizedBox(height: 16),
            if (_isCreateAccountMode) ...[
              SegmentedButton<UserRole>(
                segments: [
                  ButtonSegment<UserRole>(
                    value: UserRole.customer,
                    icon: const Icon(Icons.person_outline),
                    label: Text(settings.t('User')),
                  ),
                  ButtonSegment<UserRole>(
                    value: UserRole.artisan,
                    icon: const Icon(Icons.handyman_outlined),
                    label: Text(settings.t('Artisan')),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) {
                        setState(() => _selectedRole = selection.first);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: settings.t('Username')),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: settings.t('Email')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: settings.t('Password')),
            ),
            if (!_isCreateAccountMode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _showForgotPasswordDialog(authService),
                  child: Text(settings.t('Forgot password?')),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _isLoading
                  ? settings.t(_isCreateAccountMode
                      ? 'Creating account...'
                      : 'Signing in...')
                  : settings.t(_isCreateAccountMode
                      ? 'Create account'
                      : 'Email Sign in'),
              icon: Icons.email,
              onPressed: _isLoading
                  ? null
                  : () {
                      final validation = _isCreateAccountMode
                          ? _validateSignUp()
                          : _validateEmailPassword();
                      if (validation != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(content: Text(settings.t(validation))),
                        );
                        return;
                      }
                      if (_isCreateAccountMode) {
                        _signIn(
                          () => authService.signUpWithEmail(
                            _email,
                            _password,
                            username: _username,
                            role: _selectedRole,
                          ),
                        );
                        return;
                      }
                      _signIn(
                        () => authService.signInWithEmail(_email, _password),
                      );
                    },
            ),
            if (!_isCreateAccountMode) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: settings.t('Google Sign in'),
                icon: Icons.login,
                onPressed: _isLoading
                    ? null
                    : () => _signIn(
                          authService.signInWithGoogle,
                          forceRoleSelection: true,
                        ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(RouteNames.home),
              child: Text(settings.t('Back to homepage')),
            )
          ],
        ),
      ),
    );
  }
}
