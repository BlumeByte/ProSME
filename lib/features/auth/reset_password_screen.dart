import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/auth_service.dart';
import '../../services/service_providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _cancelRecovery() async {
    ref.read(passwordRecoveryActiveProvider.notifier).state = false;
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {}
    if (mounted) context.go(RouteNames.home);
  }

  Future<void> _updatePassword() async {
    if (_loading) return;
    final settings = ref.read(appSettingsControllerProvider);
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (password != confirmation) {
      _showMessage(settings.t('Passwords do not match.'));
      return;
    }
    if (!isStrongPassword(password)) {
      _showMessage(
        settings.t(
          'Password must be 8+ characters with uppercase, lowercase, number, and special character.',
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).updatePassword(password, '');
      ref.read(passwordRecoveryActiveProvider.notifier).state = false;
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Password updated. Sign in again.'))),
      );
      context.go(RouteNames.auth);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${settings.t('Could not update password')}: ${_messageFrom(error)}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFrom(Object error) {
    final text = error.toString();
    return text.replaceFirst(RegExp(r'^(AuthException|StateError):\s*'), '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancelRecovery();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _cancelRecovery),
          title: Text(settings.t('Create new password')),
          actions: [
            TextButton.icon(
              onPressed: _cancelRecovery,
              icon: const Icon(Icons.home_outlined),
              label: Text(settings.t('Home')),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('Choose a new password for your account.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: settings.t('New password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: settings.t('Show password'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _updatePassword(),
                      decoration: InputDecoration(
                        labelText: settings.t('Confirm password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: settings.t(
                        _loading ? 'Updating password...' : 'Update password',
                      ),
                      icon: Icons.check,
                      onPressed: _loading ? null : _updatePassword,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _loading ? null : _cancelRecovery,
                      icon: const Icon(Icons.home_outlined),
                      label: Text(settings.t('Back to homepage')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
