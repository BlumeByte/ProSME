import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../core/utils/country_preferences.dart';
import '../../core/utils/location_data.dart';
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
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_ ]{3,50}$');
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isCreateAccountMode = false;
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.customer;
  String _selectedGender = 'prefer_not_to_say';
  CountryOption _selectedCountry = countryByName('Ghana');
  List<CountryOption> _countries = kCountries;
  DateTime? _dateOfBirth;

  String get _username =>
      _usernameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;
  String get _phone {
    final value = _phoneController.text.trim();
    if (value.isEmpty) return '';
    final compact = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (compact.startsWith('+')) return compact;
    final dialDigits = _selectedCountry.dialCode.replaceFirst('+', '');
    if (compact.startsWith(dialDigits) && compact.length > dialDigits.length) {
      return '+$compact';
    }
    if (compact.startsWith('0') && compact.length > 1) {
      return '${_selectedCountry.dialCode}${compact.substring(1)}';
    }
    if (RegExp(r'^\d{8,14}$').hasMatch(compact)) {
      return '${_selectedCountry.dialCode}$compact';
    }
    return compact;
  }

  bool _isAdult(DateTime value) {
    final today = DateTime.now();
    final adultCutoff = DateTime(today.year - 18, today.month, today.day);
    return !value.isAfter(adultCutoff);
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final adultCutoff = DateTime(today.year - 18, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? adultCutoff,
      firstDate: DateTime(today.year - 100),
      lastDate: adultCutoff,
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dateOfBirthController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await loadWorldCountries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _selectedCountry = countries.firstWhere(
          (country) => country.code == _selectedCountry.code,
          orElse: () => _selectedCountry,
        );
      });
    } catch (_) {
      // Keep bundled country fallback.
    }
  }

  Future<void> _selectCountry(CountryOption country) async {
    setState(() => _selectedCountry = country);
    final defaults = preferencesForCountry(country);
    final settings = ref.read(appSettingsControllerProvider.notifier);
    await settings.setLanguage(defaults.language);
    await settings.setCurrencyCode(defaults.currencyCode);
  }

  String _friendlyError(Object error) {
    if (error is PendingEmailVerificationException) {
      return 'Account created. Click the verification link in your email, then sign in.';
    }
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (message.contains('refresh token') ||
        message.contains('session') && message.contains('expired')) {
      return 'Your saved session expired. Please sign in again.';
    }
    if (message.contains('email not confirmed') ||
        message.contains('email_not_confirmed') ||
        message.contains('confirm your email')) {
      return 'Check your email and confirm your account before signing in.';
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
    if (message.contains('confirmation') && message.contains('email')) {
      return 'Account email could not be sent. Please try again later or contact Support.';
    }
    if (message.contains('smtp') || message.contains('email service')) {
      return 'Account email service is not available right now. Please contact Support.';
    }
    if (message.contains('microsoft sign-in')) {
      return 'Microsoft sign-in is not configured yet. Check Microsoft sign-in and redirect settings.';
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

  Future<void> _showAccountActivationDialog(AuthService authService) async {
    final settings = ref.read(appSettingsControllerProvider);
    final codeController = TextEditingController();
    var resending = false;
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(settings.t('Confirm account activation')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.t(
                  'Enter the 6-digit code sent to your email, or use the confirmation link in the email.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: settings.t('6-digit code'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(settings.t('Later')),
            ),
            TextButton(
              onPressed: resending
                  ? null
                  : () async {
                      setDialogState(() => resending = true);
                      try {
                        await authService.requestSignupEmailOtp(_email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settings.t('Verification code sent.'),
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${settings.t('Could not send code')}: $error',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => resending = false);
                        }
                      }
                    },
              child: Text(settings.t(resending ? 'Sending...' : 'Resend code')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(codeController.text.trim()),
              child: Text(settings.t('Verify')),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    if (code == null || code.isEmpty) return;
    try {
      final user = await authService.verifySignupEmailOtp(_email, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Account activated.'))),
      );
      context.go(
        user.role == UserRole.artisan || _selectedRole == UserRole.artisan
            ? RouteNames.artisanVerification
            : _routeForUser(user),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not activate account')}: $error'),
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
      return 'Username must be 3-50 characters (letters, numbers, spaces, underscores).';
    }
    if (_dateOfBirth == null) {
      return 'Date of birth is required.';
    }
    if (_selectedCountry.name.trim().isEmpty) {
      return 'Country is required.';
    }
    if (!_isAdult(_dateOfBirth!)) {
      return 'You must be at least 18 years old to create an account.';
    }
    if (_phone.isNotEmpty && !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_phone)) {
      return 'Enter phone with country code, for example +233256122555.';
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
    AuthService? authService,
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      // Web: release the browser's autofill session now that the credentials
      // were accepted, so a stale session doesn't linger into the next
      // screen and interfere with editing if the user signs out and back in.
      TextInput.finishAutofillContext();
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
      if (error is PendingEmailVerificationException &&
          _isCreateAccountMode &&
          authService != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.t(
                'Account created. Check your email to verify, then sign in.',
              ),
            ),
          ),
        );
        await _showAccountActivationDialog(authService);
        return;
      }
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
    // Release the browser's autofill session if the user navigates away
    // without submitting, so it doesn't linger and interfere with a later
    // visit to this screen.
    TextInput.finishAutofillContext(shouldSave: false);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final title = _isCreateAccountMode ? 'Create account' : 'Sign in';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(RouteNames.home);
      },
      child: Scaffold(
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
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  minHeight: constraints.maxHeight,
                ),
                child: AutofillGroup(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    children: [
                      const Icon(Icons.lock_outline, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        settings.t(title),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.t(
                          _isCreateAccountMode
                              ? 'Create one account for ProSME on web and mobile.'
                              : 'Welcome back. Sign in to continue your work.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
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
                  autofillHints: const [AutofillHints.newUsername],
                  textInputAction: TextInputAction.next,
                  decoration:
                      InputDecoration(labelText: settings.t('Username')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: InputDecoration(labelText: settings.t('Gender')),
                  items: [
                    DropdownMenuItem(
                      value: 'female',
                      child: Text(settings.t('Female')),
                    ),
                    DropdownMenuItem(
                      value: 'male',
                      child: Text(settings.t('Male')),
                    ),
                    DropdownMenuItem(
                      value: 'non_binary',
                      child: Text(settings.t('Non-binary')),
                    ),
                    DropdownMenuItem(
                      value: 'prefer_not_to_say',
                      child: Text(settings.t('Prefer not to say')),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedGender = value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CountryOption>(
                  initialValue: _selectedCountry,
                  decoration: InputDecoration(labelText: settings.t('Country')),
                  items: _countries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country,
                          child: Text(country.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isLoading
                      ? null
                      : (country) {
                          if (country == null) return;
                          _selectCountry(country);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateOfBirthController,
                  autofillHints: const [AutofillHints.birthday],
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: settings.t('Date of birth'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: _isLoading ? null : _pickDateOfBirth,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: settings.t('Phone number (optional)'),
                    hintText: '${_selectedCountry.dialCode}256122555',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: settings.t('Email')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                autofillHints: _isCreateAccountMode
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: settings.t('Password'),
                  suffixIcon: IconButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: settings.t(
                      _obscurePassword ? 'Show password' : 'Hide password',
                    ),
                  ),
                ),
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
                label: settings.t(
                  _isCreateAccountMode ? 'Create account' : 'Email Sign in',
                ),
                icon: Icons.email,
                isLoading: _isLoading,
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
                              gender: _selectedGender,
                              dateOfBirth: _dateOfBirth,
                              phone: _phone,
                              country: _selectedCountry.name,
                              countryCode: _selectedCountry.dialCode,
                              appLanguage: settings.language,
                              currencyCode: settings.currencyCode,
                            ),
                            authService: authService,
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
                  isLoading: _isLoading,
                  onPressed: _isLoading
                      ? null
                      : () => _signIn(
                            authService.signInWithGoogle,
                            forceRoleSelection: true,
                          ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: settings.t('Microsoft Sign in'),
                  icon: Icons.window,
                  isLoading: _isLoading,
                  onPressed: _isLoading
                      ? null
                      : () => _signIn(
                            authService.signInWithMicrosoft,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
