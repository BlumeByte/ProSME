import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../config/constants.dart';
import '../../core/utils/location_data.dart';
import '../../models/app_user.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/auth_service.dart';
import '../../services/service_providers.dart';
import '../../services/theme_mode_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final authService = ref.read(authServiceProvider);
    if (user == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sign in to continue'),
            subtitle: const Text('Manage your profile and settings.'),
            onTap: () => context.go(RouteNames.auth),
          ),
        ],
      );
    }

    final normalizedName = user.name.trim();
    final firstName = normalizedName.isEmpty
        ? 'there'
        : normalizedName.split(RegExp(r'\s+')).first;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, $firstName',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _ProfilePhotoHeader(
          user: user,
          uploading: _uploadingPhoto,
          onChangePhoto: () => _changeProfilePhoto(authService),
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Favourites'),
        const SizedBox(height: 12),
        _FavouritesBlock(userId: user.id),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Profile'),
        const SizedBox(height: 8),
        if (user.role == UserRole.artisan) ...[
          _SettingsTile(
            icon: user.verificationStatus == VerificationStatus.verified
                ? Icons.verified
                : Icons.pending_actions_outlined,
            title: user.verificationStatus == VerificationStatus.verified
                ? 'Verified artisan'
                : 'Verification ${user.verificationStatus.name}',
            subtitle: user.verificationStatus == VerificationStatus.verified
                ? 'Your profile shows a public verified checkmark.'
                : 'Submit or update your ID for Support review.',
            trailingText: user.verificationStatus == VerificationStatus.verified
                ? null
                : 'Upload',
            onTap: user.verificationStatus == VerificationStatus.verified
                ? null
                : () => context.go(RouteNames.artisanVerification),
          ),
          const Divider(),
        ],
        _SettingsTile(
          icon: Icons.manage_accounts_outlined,
          title: 'Account settings',
          subtitle: 'Username, phone, email, password, and privacy.',
          trailingText: 'Open',
          onTap: () =>
              _showAccountSettingsSheet(context, ref, authService, user),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.tune_outlined,
          title: 'App settings',
          subtitle: 'Language, dark mode, and notifications.',
          trailingText: 'Open',
          onTap: () => _showAppSettingsSheet(context, ref, user),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () => authService.signOut(),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'Delete account',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () => _confirmDeleteAccount(context, authService),
        ),
      ],
    );
  }

  Future<void> _changeProfilePhoto(AuthService authService) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final originalBytes = await file.readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        throw StateError('Choose a valid image file.');
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 512 : null,
        height: decoded.height >= decoded.width ? 512 : null,
      );
      final compressed = img.encodeJpg(resized, quality: 72);
      await authService.updatePhoto(
        Uint8List.fromList(compressed),
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update image: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }
}

Future<void> _showChangeUsernameDialog(
  BuildContext context,
  AuthService authService,
  String currentUsername,
) async {
  final requestSent = await _sendEmailOtp(context, authService);
  if (!requestSent) return;
  if (!context.mounted) return;

  final result = await _showUsernameOtpDialog(
    context: context,
    currentUsername: currentUsername,
  );

  if (result == null) return;
  final (nextUsername, otp) = result;
  if (nextUsername.isEmpty || otp.isEmpty) return;

  try {
    await authService.updateUsername(nextUsername, emailOtp: otp);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update username: $error')),
      );
    }
  }
}

Future<bool> _sendEmailOtp(
  BuildContext context,
  AuthService authService,
) async {
  try {
    await authService.requestEmailOtp();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verification code sent.')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send email code: $error')),
      );
    }
    return false;
  }
}

Future<(String username, String otp)?> _showUsernameOtpDialog({
  required BuildContext context,
  required String currentUsername,
}) async {
  final usernameController = TextEditingController(text: currentUsername);
  final otpController = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'New username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Email code'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (usernameController.text.trim(), otpController.text.trim()),
          ),
          child: const Text('Verify and save'),
        ),
      ],
    ),
  );
  usernameController.dispose();
  otpController.dispose();
  return result;
}

Future<void> _showSecuritySheet(
  BuildContext context,
  AuthService authService,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Security',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change password'),
              subtitle: const Text('Requires an email verification code.'),
              onTap: () {
                Navigator.of(context).pop();
                _showChangePasswordDialog(context, authService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: const Text('Email verification'),
              subtitle: const Text('Security codes are sent by Supabase Auth.'),
              onTap: () => _sendEmailOtp(context, authService),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showChangePasswordDialog(
  BuildContext context,
  AuthService authService,
) async {
  final requestSent = await _sendEmailOtp(context, authService);
  if (!requestSent) return;
  if (!context.mounted) return;

  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final otpController = TextEditingController();
  final result = await showDialog<(String, String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Email code'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (
              passwordController.text,
              confirmController.text,
              otpController.text.trim(),
            ),
          ),
          child: const Text('Update password'),
        ),
      ],
    ),
  );
  passwordController.dispose();
  confirmController.dispose();
  otpController.dispose();
  if (result == null) return;
  final (password, confirm, otp) = result;
  if (password != confirm) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
    }
    return;
  }
  try {
    await authService.updatePassword(password, otp);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update password: $error')),
      );
    }
  }
}

Future<void> _showChangePhoneDialog(
  BuildContext context,
  AuthService authService,
  String currentPhone,
  String currentCountry,
) async {
  var selectedCountry = countryByName(currentCountry);
  final controller = TextEditingController(text: currentPhone);
  final nextPhone = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Change phone number'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CountryOption>(
                initialValue: selectedCountry,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Country'),
                items: kCountries
                    .map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(
                          '${country.name} (${country.dialCode})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (country) {
                  if (country == null) return;
                  setDialogState(() => selectedCountry = country);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '${selectedCountry.dialCode} ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();

  if (nextPhone == null || nextPhone.isEmpty) return;
  if (!isValidPhoneForCountry(nextPhone, selectedCountry)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid ${selectedCountry.name} phone number.'),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  final code = await _showPhoneCodeDialog(
    context,
    formatPhoneForCountry(nextPhone, selectedCountry),
  );
  if (code == null) return;
  if (code.trim().length < 4) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the verification code.')),
      );
    }
    return;
  }

  try {
    await authService.updateCountry(
        selectedCountry.name, selectedCountry.dialCode);
    await authService
        .updatePhone(formatPhoneForCountry(nextPhone, selectedCountry));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number saved.'),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update phone number: $error')),
      );
    }
  }
}

Future<String?> _showPhoneCodeDialog(
  BuildContext context,
  String phone,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm phone number'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the text code sent to $phone. If SMS is not configured yet, use your test code.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Verify'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> _showCountryDialog(
  BuildContext context,
  AuthService authService,
  String currentCountry,
) async {
  final selected = await showModalBottomSheet<CountryOption>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: kCountries
            .map(
              (country) => ListTile(
                leading: const Icon(Icons.public_outlined),
                title: Text(country.name),
                subtitle: Text(country.dialCode),
                selected: country.name == currentCountry,
                onTap: () => Navigator.of(context).pop(country),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
  if (selected == null) return;
  try {
    await authService.updateCountry(selected.name, selected.dialCode);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country updated.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update country: $error')),
      );
    }
  }
}

Future<void> _showDescriptionDialog(
  BuildContext context,
  AuthService authService,
  String currentDescription,
) async {
  final description = await _showEditDialog(
    context: context,
    title: 'Profile description',
    hintText: 'What do you do?',
    initialValue: currentDescription,
    maxLength: 50,
  );
  if (description == null) return;
  try {
    await authService.updateDescription(description);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile description updated.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update description: $error')),
      );
    }
  }
}

Future<void> _showChangeEmailDialog(
  BuildContext context,
  AuthService authService,
  String currentEmail,
) async {
  final nextEmail = await _showEditDialog(
    context: context,
    title: 'Change email',
    hintText: 'Enter email address',
    initialValue: currentEmail,
    keyboardType: TextInputType.emailAddress,
  );

  if (nextEmail == null || nextEmail.isEmpty) return;

  try {
    await authService.updateEmail(nextEmail);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email update submitted. Check your inbox if verification is required.',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update email: $error')),
      );
    }
  }
}

Future<String?> _showEditDialog({
  required BuildContext context,
  required String title,
  required String hintText,
  required String initialValue,
  TextInputType? keyboardType,
  int? maxLength,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(hintText: hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> _showInfoSheet(
  BuildContext context,
  String title,
  String message,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showAppSettingsSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  var isDarkMode = ref.read(themeModeControllerProvider) == ThemeMode.dark;
  var settings = ref.read(appSettingsControllerProvider);
  var emailNotifications = settings.emailNotifications;
  var phoneNotifications = settings.phoneNotifications;
  var language = settings.language;
  const languages = [
    'English',
    'Arabic',
    'Bengali',
    'Chinese',
    'Dutch',
    'Ewe',
    'French',
    'Ga',
    'German',
    'Greek',
    'Hausa',
    'Hindi',
    'Indonesian',
    'Italian',
    'Japanese',
    'Korean',
    'Malay',
    'Portuguese',
    'Russian',
    'Spanish',
    'Swahili',
    'Tamil',
    'Thai',
    'Twi',
    'Turkish',
    'Ukrainian',
    'Urdu',
    'Vietnamese',
    'Yoruba',
    'Zulu',
  ];
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'App settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  value: isDarkMode,
                  onChanged: (value) {
                    setSheetState(() => isDarkMode = value);
                    ref
                        .read(themeModeControllerProvider.notifier)
                        .setDarkMode(value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.email_outlined),
                  title: const Text('Email notifications'),
                  value: emailNotifications,
                  onChanged: (value) async {
                    setSheetState(() => emailNotifications = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setEmailNotifications(value);
                    await _saveRemoteSettings(ref, user);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Phone notifications'),
                  value: phoneNotifications,
                  onChanged: (value) async {
                    setSheetState(() => phoneNotifications = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setPhoneNotifications(value);
                    await _saveRemoteSettings(ref, user);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    prefixIcon: Icon(Icons.language_outlined),
                  ),
                  items: languages
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) async {
                    if (value == null) return;
                    setSheetState(() => language = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setLanguage(value);
                    await _saveRemoteSettings(ref, user);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showAccountSettingsSheet(
  BuildContext context,
  WidgetRef ref,
  AuthService authService,
  AppUser user,
) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Account settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(user.name),
                subtitle: const Text('Username or company display name'),
                trailing: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showChangeUsernameDialog(context, authService, user.name);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(user.phone.isEmpty ? 'Add phone' : user.phone),
                subtitle: const Text('Phone number and country code'),
                trailing: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showChangePhoneDialog(
                    context,
                    authService,
                    user.phone,
                    user.country,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_outlined),
                title: Text(user.country),
                subtitle: Text('Country code ${user.countryCode}'),
                trailing: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCountryDialog(context, authService, user.country);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(
                  user.description.isEmpty
                      ? 'Add profile description'
                      : user.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  user.role == UserRole.artisan
                      ? 'Company or artisan profile description'
                      : 'Customer profile description',
                ),
                trailing: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDescriptionDialog(
                    context,
                    authService,
                    user.description,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alternate_email_outlined),
                title: Text(user.email),
                trailing: const Text('Edit'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showChangeEmailDialog(context, authService, user.email);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security_outlined),
                title: const Text('Account security'),
                subtitle: const Text(
                  'Email codes, password recovery, and Google verification are handled by Supabase.',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSecuritySheet(context, authService);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(RouteNames.privacy);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Support'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(RouteNames.aiSupport);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(RouteNames.terms);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInfoSheet(
                    context,
                    'About Pro SME',
                    'Pro SME helps customers connect with verified SMEs and artisans.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _saveRemoteSettings(WidgetRef ref, AppUser user) async {
  if (!shouldUseSupabase()) return;
  final settings = ref.read(appSettingsControllerProvider);
  try {
    await ref.read(supabaseClientProvider).from('profiles').update({
      'email_notifications': settings.emailNotifications,
      'phone_notifications': settings.phoneNotifications,
      'app_language': settings.language,
    }).eq('id', user.id);
  } catch (_) {
    // Local settings still apply immediately; remote sync can retry next edit.
  }
}

Future<void> _confirmDeleteAccount(
  BuildContext context,
  AuthService authService,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete account'),
      content: const Text(
        'This will permanently remove your account. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await authService.deleteAccount();
    if (context.mounted) {
      context.go(RouteNames.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $error')),
      );
    }
  }
}

class _ProfilePhotoHeader extends StatelessWidget {
  const _ProfilePhotoHeader({
    required this.user,
    required this.uploading,
    required this.onChangePhoto,
  });

  final AppUser user;
  final bool uploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageProvider = _profileImageProvider(user.photoUrl);
    final hasPhoto = imageProvider != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: imageProvider,
                child: uploading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : hasPhoto
                        ? null
                        : Text(
                            user.name.trim().isEmpty
                                ? 'U'
                                : user.name.trim()[0].toUpperCase(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
              ),
              IconButton.filled(
                onPressed: uploading ? null : onChangePhoto,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                tooltip: 'Change profile image',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user.description.trim().isEmpty
                ? (user.role == UserRole.artisan
                    ? 'Artisan profile'
                    : 'Customer profile')
                : user.description.trim(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  ImageProvider? _profileImageProvider(String value) {
    if (value.trim().isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
    }
    return NetworkImage(value);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = trailingText == null
        ? (onTap == null ? null : const Icon(Icons.chevron_right))
        : Text(
            trailingText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Shows the live count of saved listings and taps through to [SavedScreen].
class _FavouritesBlock extends ConsumerWidget {
  const _FavouritesBlock({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final savedIdsAsync = ref.watch(savedListingIdsProvider(userId));

    final count = savedIdsAsync.valueOrNull?.length ?? 0;
    final hasAny = count > 0;

    return GestureDetector(
      onTap: () => context.push(RouteNames.saved),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAny
                        ? '$count saved listing${count == 1 ? '' : 's'}'
                        : 'No favourites added',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAny
                        ? 'Tap to view your saved listings.'
                        : 'Save all your favourites in one place using the bookmark icon.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.primary,
              child: const Icon(Icons.bookmark, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
