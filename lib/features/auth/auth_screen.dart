import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        context.go(RouteNames.role);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
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
              label: _isLoading ? 'Signing in...' : 'Email Sign in',
              icon: Icons.email,
              onPressed: _isLoading
                  ? () {}
                  : () => _signIn(() => authService.signInWithEmail(
                        _emailController.text,
                        _passwordController.text,
                      )),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Google Sign in',
              icon: Icons.login,
              onPressed: _isLoading
                  ? () {}
                  : () => _signIn(authService.signInWithGoogle),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone (OTP)'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Phone Sign in',
              icon: Icons.phone,
              onPressed: _isLoading
                  ? () {}
                  : () => _signIn(
                        () => authService.signInWithPhone(
                          _phoneController.text,
                        ),
                      ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(RouteNames.onboarding),
              child: const Text('Back'),
            )
          ],
        ),
      ),
    );
  }
}
