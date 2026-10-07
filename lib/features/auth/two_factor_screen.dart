import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

/// Holds a password sign-in until the emailed 6-digit code is entered. The
/// router keeps a user with `twoFactorPending` on this screen, so no other part
/// of the app is reachable until the code is verified.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _codeController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _friendly(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^(StateError|Exception|Bad state):\s*'), '')
        .trim();
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  Future<void> _sendCode() async {
    if (_sending || _verifying) return;
    final settings = ref.read(appSettingsControllerProvider);
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).requestEmailOtp();
      if (!mounted) return;
      setState(() => _info = settings.t('Code sent. Check your inbox and spam folder.'));
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final settings = ref.read(appSettingsControllerProvider);
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = settings.t('Enter the 6-digit code.'));
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyEmailOtp(code);
      // Releases the router gate; the redirect then sends the user home.
      await authService.completeTwoFactor();
      // Do not wait on the router to notice the change: go straight to the app.
      if (mounted) context.go(RouteNames.home);
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _cancel() async {
    await ref.read(authServiceProvider).cancelTwoFactor();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('Two-factor verification')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Icon(Icons.shield_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  settings.t(
                    'Enter the 6-digit code we emailed you to finish signing in.',
                  ),
                  textAlign: TextAlign.center,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _maskEmail(email),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: settings.t('6-digit code'),
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verifying ? null : _verify(),
                ),
                if (_info != null && _error == null) ...[
                  const SizedBox(height: 8),
                  Text(_info!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verifying ? null : _verify,
                  child: Text(
                    settings.t(_verifying ? 'Verifying...' : 'Verify'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sending || _verifying ? null : _sendCode,
                  child: Text(
                    settings.t(_sending ? 'Sending...' : 'Resend code'),
                  ),
                ),
                TextButton(
                  onPressed: _verifying ? null : _cancel,
                  child: Text(settings.t('Cancel sign in')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
