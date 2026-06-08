import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../models/app_user.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
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
      return 'Google sign-in is not configured yet. Check Supabase Google provider and redirect URL.';
    }
    if (message.contains('otp sent')) {
      return 'OTP sent. Check your SMS messages.';
    }
    return 'Something went wrong. Please try again.';
  }

  String? _validateEmailPassword() {
    if (_email.isEmpty || _password.isEmpty) {
      return 'Please enter email and password.';
    }
    if (!_emailPattern.hasMatch(_email)) {
      return 'Please enter a valid email.';
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
      case UserRole.developer:
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
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
    final title = _isCreateAccountMode ? 'Create account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Sign in')),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Create account'),
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
                segments: const [
                  ButtonSegment<UserRole>(
                    value: UserRole.customer,
                    icon: Icon(Icons.person_outline),
                    label: Text('User'),
                  ),
                  ButtonSegment<UserRole>(
                    value: UserRole.artisan,
                    icon: Icon(Icons.handyman_outlined),
                    label: Text('Artisan'),
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
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _isLoading
                  ? (_isCreateAccountMode
                      ? 'Creating account...'
                      : 'Signing in...')
                  : (_isCreateAccountMode ? 'Create account' : 'Email Sign in'),
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
                        ).showSnackBar(SnackBar(content: Text(validation)));
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
                label: 'Google Sign in',
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
              child: const Text('Back'),
            )
          ],
        ),
      ),
    );
  }
}
