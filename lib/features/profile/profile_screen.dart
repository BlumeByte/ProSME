import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/location_data.dart';
import '../../models/app_user.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
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
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final authService = ref.read(authServiceProvider);
    if (user == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Text(settings.t('Profile'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(settings.t('Sign in to continue')),
            subtitle: Text(settings.t('Manage your profile and settings.')),
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
          '${settings.t('Hello')}, $firstName',
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
        _SectionTitle(title: settings.t('Favourites')),
        const SizedBox(height: 12),
        _FavouritesBlock(userId: user.id),
        const SizedBox(height: 26),
        _SectionTitle(title: settings.t('Profile')),
        const SizedBox(height: 8),
        if (user.role == UserRole.artisan) ...[
          SwitchListTile(
            secondary: Icon(
              user.isBusy ? Icons.block : Icons.check_circle_outline,
              color: user.isBusy ? Colors.red : Colors.green,
            ),
            title: Text(settings.t('Mark services unavailable')),
            subtitle: Text(
              user.isBusy
                  ? settings
                      .t('Chat and booking buttons show unavailable to users.')
                  : settings.t('Users can chat and book your active services.'),
            ),
            value: user.isBusy,
            onChanged: (value) async {
              try {
                await authService.updateAvailability(isBusy: value);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? settings.t('Services marked unavailable.')
                          : settings.t('Services marked available.'),
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${settings.t('Could not update status')}: $error'),
                  ),
                );
              }
            },
          ),
          const Divider(),
        ],
        _SettingsTile(
          icon: user.verificationStatus == VerificationStatus.verified
              ? Icons.verified
              : Icons.pending_actions_outlined,
          title: user.verificationStatus == VerificationStatus.verified
              ? (user.role == UserRole.artisan
                  ? settings.t('Verified artisan')
                  : settings.t('Verified account'))
              : '${settings.t('Verification')} ${user.verificationStatus.name}',
          subtitle: user.verificationStatus == VerificationStatus.verified
              ? settings.t('Your profile shows a public verified checkmark.')
              : settings.t('Submit or update your ID for Support review.'),
          trailingText: user.verificationStatus == VerificationStatus.verified
              ? null
              : settings.t('Upload'),
          onTap: user.verificationStatus == VerificationStatus.verified
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(settings.t('Your account is already verified.')),
                    ),
                  )
              : () => context.push(RouteNames.artisanVerification),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.manage_accounts_outlined,
          title: settings.t('Account settings'),
          subtitle:
              settings.t('Username, phone, email, password, and privacy.'),
          trailingText: settings.t('Open'),
          onTap: () =>
              _showAccountSettingsSheet(context, ref, authService, user),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.tune_outlined,
          title: settings.t('App settings'),
          subtitle: settings.t('Language, dark mode, and notifications.'),
          trailingText: settings.t('Open'),
          onTap: () => _showAppSettingsSheet(context, ref, user),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: settings.t('Notifications'),
          subtitle: settings.t('History, bid, chat, and account alerts.'),
          trailingText: settings.t('Open'),
          onTap: () => context.push(RouteNames.notifications),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.history_outlined,
          title: settings.t('Work history'),
          subtitle: settings.t('Accepted and rejected bids and requests.'),
          trailingText: settings.t('Open'),
          onTap: () => context.push(RouteNames.workHistory),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: settings.t('Wallet'),
          subtitle: settings.t('Track accepted bids and money flow.'),
          trailingText: settings.t('Open'),
          onTap: () => context.push(RouteNames.wallet),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(settings.t('Logout')),
          onTap: () => authService.signOut(),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: Text(
            settings.t('Delete account'),
            style: const TextStyle(color: Colors.red),
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
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Profile image updated.'))),
      );
    } catch (error) {
      if (!mounted) return;
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${settings.t('Could not update image')}: $error')),
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
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final nextUsername = await _showUsernameDialog(
    context: context,
    currentUsername: currentUsername,
  );

  if (nextUsername == null || nextUsername.isEmpty) return;

  try {
    await authService.updateUsername(nextUsername);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Username updated.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not update username')}: $error'),
        ),
      );
    }
  }
}

Future<String?> _showUsernameDialog({
  required BuildContext context,
  required String currentUsername,
}) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final usernameController = TextEditingController(text: currentUsername);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t('Change username')),
      content: TextField(
        controller: usernameController,
        decoration: InputDecoration(labelText: settings.t('New username')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(usernameController.text.trim()),
          child: Text(settings.t('Save')),
        ),
      ],
    ),
  );
  usernameController.dispose();
  return result;
}

Future<void> _showFullNameDialog(
  BuildContext context,
  AuthService authService,
  String currentFullName,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final controller = TextEditingController(text: currentFullName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t('Change full name')),
      content: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: settings.t('Full name')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(settings.t('Save')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.trim().isEmpty) return;

  try {
    await authService.updateFullName(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Full name updated.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not update full name')}: $error'),
        ),
      );
    }
  }
}

Future<void> _showSecuritySheet(
  BuildContext context,
  AuthService authService,
  AppUser user,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
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
                    settings.t('Security'),
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
              title: Text(settings.t('Change password')),
              subtitle: Text(settings.t('Updates your password directly.')),
              onTap: () {
                Navigator.of(context).pop();
                _showChangePasswordDialog(context, authService);
              },
            ),
            ListTile(
              leading: Icon(
                user.emailVerified
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              title: Text(settings.t('Email verification')),
              subtitle: Text(
                user.emailVerified
                    ? settings.t('Your email is verified.')
                    : '${settings.t('Send a 6-digit code to')} ${user.email}.',
              ),
              trailing:
                  user.emailVerified ? Text(settings.t('Verified')) : null,
              onTap: user.emailVerified
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _showVerificationCodeDialog(
                        context,
                        title: 'Verify email',
                        requestCode: authService.requestEmailOtp,
                        verifyCode: authService.verifyEmailOtp,
                      );
                    },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android_outlined),
              title: Text(settings.t('Phone number')),
              subtitle: Text(
                user.phone.isEmpty
                    ? settings.t('Add a phone number in account settings.')
                    : user.phone,
              ),
              onTap: null,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showVerificationCodeDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function() requestCode,
  required Future<void> Function(String code) verifyCode,
}) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await requestCode();
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(settings.t('Verification code sent.'))),
      );
    }
  } catch (error) {
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${settings.t('Could not send code')}: $error')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t(title)),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: InputDecoration(labelText: settings.t('6-digit code')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(settings.t('Verify')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (code == null || code.isEmpty) return;
  try {
    await verifyCode(code);
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(settings.t('Verification complete.'))),
      );
    }
  } catch (error) {
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('${settings.t('Could not verify code')}: $error')),
      );
    }
  }
}

Future<void> _showChangePasswordDialog(
  BuildContext context,
  AuthService authService,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t('Change password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: settings.t('New password')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration:
                InputDecoration(labelText: settings.t('Confirm password')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (
              passwordController.text,
              confirmController.text,
            ),
          ),
          child: Text(settings.t('Update password')),
        ),
      ],
    ),
  );
  passwordController.dispose();
  confirmController.dispose();
  if (result == null) return;
  final (password, confirm) = result;
  if (password != confirm) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Passwords do not match.'))),
      );
    }
    return;
  }
  try {
    await authService.updatePassword(password, '');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Password updated.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not update full name')}: $error'),
        ),
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
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final countries = await loadWorldCountries();
  if (!context.mounted) return;
  var selectedCountry = countries.firstWhere(
    (country) => country.name == currentCountry,
    orElse: () =>
        countries.isNotEmpty ? countries.first : countryByName(currentCountry),
  );
  final currentDigits = currentPhone.replaceAll(RegExp(r'\D'), '');
  final countryCodeDigits =
      selectedCountry.dialCode.replaceAll(RegExp(r'\D'), '');
  final localPhone = currentDigits.startsWith(countryCodeDigits)
      ? currentDigits.substring(countryCodeDigits.length)
      : currentPhone;
  final controller = TextEditingController(text: localPhone);
  final nextPhone = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(settings.t('Change phone number')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CountryOption>(
                initialValue: selectedCountry,
                isExpanded: true,
                decoration: InputDecoration(labelText: settings.t('Country')),
                items: countries
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
                  labelText: settings.t('Phone number'),
                  prefixText: '${selectedCountry.dialCode} ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(settings.t('Save')),
          ),
        ],
      ),
    ),
  );
  controller.dispose();

  if (nextPhone == null || nextPhone.isEmpty) return;
  if (!isValidPhoneForCountry(nextPhone, selectedCountry)) {
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${settings.t('Enter a valid')} ${selectedCountry.name} ${settings.t('phone number.')}',
          ),
        ),
      );
    }
    return;
  }

  try {
    await authService.updatePhoneAndCountry(
      phone: formatPhoneForCountry(nextPhone, selectedCountry),
      country: selectedCountry.name,
      countryCode: selectedCountry.dialCode,
    );
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(settings.t('Phone number saved.')),
        ),
      );
    }
  } catch (error) {
    if (context.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('${settings.t('Could not update phone number')}: $error'),
        ),
      );
    }
  }
}

Future<void> _showCountryDialog(
  BuildContext context,
  AuthService authService,
  String currentCountry,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final countries = await loadWorldCountries();
  if (!context.mounted) return;
  final selected = await showModalBottomSheet<CountryOption>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: countries
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
        SnackBar(content: Text(settings.t('Country updated.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not update country')}: $error'),
        ),
      );
    }
  }
}

Future<void> _showDescriptionDialog(
  BuildContext context,
  AuthService authService,
  String currentDescription,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
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
        SnackBar(content: Text(settings.t('Profile description updated.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${settings.t('Could not update description')}: $error'),
        ),
      );
    }
  }
}

Future<void> _showChangeEmailDialog(
  BuildContext context,
  AuthService authService,
  String currentEmail,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
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
        SnackBar(
          content: Text(
            settings.t(
              'Email update submitted. Check your inbox if verification is required.',
            ),
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${settings.t('Could not update email')}: $error')),
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
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t(title)),
      content: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(hintText: settings.t(hintText)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(settings.t('Save')),
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
  var language = kSupportedAppLanguages.contains(settings.language)
      ? settings.language
      : 'English';
  var currencyCode = settings.currencyCode;
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
                        settings.t('App settings'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: settings.t('Close'),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(settings.t('Dark mode')),
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
                  title: Text(settings.t('Email notifications')),
                  value: emailNotifications,
                  onChanged: (value) async {
                    setSheetState(() => emailNotifications = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setEmailNotifications(value);
                    if (value) await NotificationService().requestPermissions();
                    await _saveRemoteSettings(ref, user);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(settings.t('Phone notifications')),
                  value: phoneNotifications,
                  onChanged: (value) async {
                    setSheetState(() => phoneNotifications = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setPhoneNotifications(value);
                    if (value) await NotificationService().requestPermissions();
                    await _saveRemoteSettings(ref, user);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: settings.t('Language'),
                    prefixIcon: const Icon(Icons.language_outlined),
                  ),
                  items: kSupportedAppLanguages
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
                DropdownButtonFormField<String>(
                  initialValue: currencyCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: settings.t('Currency'),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  items: kCurrencyOptions
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency.code,
                          child: Text(
                            '${currency.code} - ${currency.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) async {
                    if (value == null) return;
                    setSheetState(() => currencyCode = value);
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setCurrencyCode(value);
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
  final settings = ref.read(appSettingsControllerProvider);
  final parentContext = context;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, sheetRef, _) {
        final currentUser =
            sheetRef.watch(authStateProvider).valueOrNull ?? user;
        return SafeArea(
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
                          settings.t('Account settings'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: settings.t('Close'),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(currentUser.name),
                    subtitle: Text(settings.t('Username')),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showChangeUsernameDialog(
                        context,
                        authService,
                        currentUser.name,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(
                      currentUser.fullName.trim().isEmpty
                          ? settings.t('Add full name')
                          : currentUser.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      currentUser.role == UserRole.artisan
                          ? settings.t('Full name or business contact name')
                          : settings.t('Full name'),
                    ),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showFullNameDialog(
                        context,
                        authService,
                        currentUser.fullName.trim().isEmpty
                            ? currentUser.name
                            : currentUser.fullName,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(currentUser.phone.isEmpty
                        ? settings.t('Add phone')
                        : currentUser.phone),
                    subtitle: Text(settings.t('Phone number and country code')),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showChangePhoneDialog(
                        context,
                        authService,
                        currentUser.phone,
                        currentUser.country,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public_outlined),
                    title: Text(currentUser.country),
                    subtitle: Text(
                      '${settings.t('Country code')} ${currentUser.countryCode}',
                    ),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showCountryDialog(
                        context,
                        authService,
                        currentUser.country,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(
                      currentUser.description.isEmpty
                          ? settings.t('Add profile description')
                          : currentUser.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      currentUser.role == UserRole.artisan
                          ? settings.t('Company or artisan profile description')
                          : settings.t('Customer profile description'),
                    ),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showDescriptionDialog(
                        context,
                        authService,
                        currentUser.description,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alternate_email_outlined),
                    title: Text(currentUser.email),
                    trailing: Text(settings.t('Edit')),
                    onTap: () {
                      _showChangeEmailDialog(
                        context,
                        authService,
                        currentUser.email,
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.security_outlined),
                    title: Text(settings.t('Account security')),
                    subtitle: Text(
                      settings.t(
                        'Email codes, password recovery, and Google verification are handled by Supabase.',
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showSecuritySheet(
                        parentContext,
                        authService,
                        currentUser,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(settings.t('Privacy')),
                    onTap: () {
                      Navigator.of(context).pop();
                      parentContext.push(RouteNames.privacy);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.support_agent_outlined),
                    title: Text(settings.t('Support')),
                    onTap: () {
                      Navigator.of(context).pop();
                      parentContext.push(RouteNames.aiSupport);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(settings.t('Terms of Service')),
                    onTap: () {
                      Navigator.of(context).pop();
                      parentContext.push(RouteNames.terms);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(settings.t('About')),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showInfoSheet(
                        parentContext,
                        settings.t('About Pro SME'),
                        settings.t(
                          'Pro SME helps customers connect with verified SMEs and artisans.',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      'currency_code': settings.currencyCode,
    }).eq('id', user.id);
  } catch (_) {
    // Local settings still apply immediately; remote sync can retry next edit.
  }
}

Future<void> _confirmDeleteAccount(
  BuildContext context,
  AuthService authService,
) async {
  final settings =
      ProviderScope.containerOf(context).read(appSettingsControllerProvider);
  final reasonController = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t('Delete account')),
      content: TextField(
        controller: reasonController,
        minLines: 3,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: settings.t('Why are you deleting your account?'),
          hintText: settings.t('Your feedback helps us improve ProSME.'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final value = reasonController.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(settings.t('Continue')),
        ),
      ],
    ),
  );
  reasonController.dispose();

  if (reason == null || reason.trim().isEmpty) return;
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(settings.t('Are you sure?')),
      content: Text(
        settings.t(
          'This will permanently remove your account. This action cannot be undone.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(settings.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(settings.t('Delete account')),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await authService.deleteAccount(reason: reason);
    if (context.mounted) {
      context.go(RouteNames.home);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Account deleted.'))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not delete account')}: $error'),
        ),
      );
    }
  }
}

class _ProfilePhotoHeader extends ConsumerWidget {
  const _ProfilePhotoHeader({
    required this.user,
    required this.uploading,
    required this.onChangePhoto,
  });

  final AppUser user;
  final bool uploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
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
                tooltip: settings.t('Change profile image'),
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
                    ? settings.t('Artisan profile')
                    : settings.t('Customer profile'))
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
    final settings = ref.watch(appSettingsControllerProvider);
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
                        ? '$count ${settings.t(count == 1 ? 'saved listing' : 'saved listings')}'
                        : settings.t('No favourites added'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAny
                        ? settings.t('Tap to view your saved listings.')
                        : settings.t(
                            'Save all your favourites in one place using the bookmark icon.'),
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
