import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/service_providers.dart';
import '../../services/theme_mode_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _paymentMethodKey = 'profile_payment_method';
  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    _loadPaymentMethod();
  }

  Future<void> _loadPaymentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_paymentMethodKey);
    if (!mounted || stored == null || stored.isEmpty) return;
    setState(() => _paymentMethod = stored);
  }

  Future<void> _persistPaymentMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentMethodKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final authService = ref.read(authServiceProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

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
            subtitle: const Text('Manage your profile, payments, and settings.'),
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
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Favourites'),
        const SizedBox(height: 12),
        _FavouritesBlock(userId: user.id),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(child: _SectionTitle(title: 'Payment')),
            TextButton(
              onPressed: () => _showPaymentMethodDialog(context),
              child: const Text('Edit'),
            ),
          ],
        ),
        _SettingsTile(
          icon: Icons.payments_outlined,
          title: _paymentMethod,
          subtitle: 'Change',
          onTap: () => _showPaymentMethodDialog(context),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'ProSME Balance',
          subtitle: 'GHS 0.00',
          onTap: () => _showInfoSheet(
            context,
            'ProSME Balance',
            'Your wallet balance is GHS 0.00. Payments and refunds will appear here.',
          ),
        ),
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
                : 'Submit or update your ID for admin review.',
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
          icon: Icons.person_outline,
          title: user.name,
          trailingText: 'Edit',
          onTap: () => _showChangeUsernameDialog(context, authService, user.name),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.phone_outlined,
          title: user.phone.isNotEmpty ? user.phone : 'Add phone',
          trailingText: 'Edit',
          onTap: () => _showChangePhoneDialog(context, authService, user.phone),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.alternate_email_outlined,
          title: user.email,
          trailingText: 'Edit',
          onTap: () => _showChangeEmailDialog(context, authService, user.email),
        ),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Other'),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.local_offer_outlined,
          title: 'Promo codes',
          onTap: () => _showPromoCodeDialog(context),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => _showSettingsSheet(context, ref),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.shield_outlined,
          title: 'Privacy',
          onTap: () => _showInfoSheet(
            context,
            'Privacy',
            'Your account data is stored securely in Supabase and only visible to you.',
          ),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () => _showInfoSheet(
            context,
            'About Pro SME',
            'Pro SME helps customers connect with verified SMEs and artisans.',
          ),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.support_agent_outlined,
          title: 'Support',
          onTap: () => context.go(RouteNames.aiSupport),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Dark mode'),
          value: isDarkMode,
          onChanged: (value) {
            ref.read(themeModeControllerProvider.notifier).setDarkMode(value);
          },
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

  Future<void> _showPaymentMethodDialog(BuildContext context) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Cash'),
              onTap: () => Navigator.of(context).pop('Cash'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android_outlined),
              title: const Text('Mobile Money'),
              onTap: () => Navigator.of(context).pop('Mobile Money'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (method == null || !mounted) return;
    setState(() => _paymentMethod = method);
    await _persistPaymentMethod(method);
  }
}

Future<void> _showChangeUsernameDialog(
  BuildContext context,
  AuthService authService,
  String currentUsername,
) async {
  final nextUsername = await _showEditDialog(
    context: context,
    title: 'Change username',
    hintText: 'Enter new username',
    initialValue: currentUsername,
  );

  if (nextUsername == null || nextUsername.isEmpty) return;

  try {
    await authService.updateUsername(nextUsername);
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

Future<void> _showChangePhoneDialog(
  BuildContext context,
  AuthService authService,
  String currentPhone,
) async {
  final nextPhone = await _showEditDialog(
    context: context,
    title: 'Change phone number',
    hintText: 'Enter phone number',
    initialValue: currentPhone,
    keyboardType: TextInputType.phone,
  );

  if (nextPhone == null || nextPhone.isEmpty) return;

  try {
    await authService.updatePhone(nextPhone);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number updated.')),
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
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

Future<void> _showPromoCodeDialog(BuildContext context) async {
  final code = await _showEditDialog(
    context: context,
    title: 'Promo code',
    hintText: 'Enter promo code',
    initialValue: '',
  );
  if (!context.mounted || code == null || code.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Promo code "$code" applied.')),
  );
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

Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  var isDarkMode = ref.read(themeModeControllerProvider) == ThemeMode.dark;
  var emailNotifications =
      prefs.getBool('settings_email_notifications') ?? true;
  var smsNotifications = prefs.getBool('settings_sms_notifications') ?? true;
  var language = prefs.getString('settings_language') ?? 'English';
  const languages = ['English', 'Twi', 'Ewe', 'Ga', 'French', 'Spanish'];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
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
                  ref.read(themeModeControllerProvider.notifier).setDarkMode(value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.email_outlined),
                title: const Text('Email notifications'),
                value: emailNotifications,
                onChanged: (value) async {
                  setSheetState(() => emailNotifications = value);
                  await prefs.setBool('settings_email_notifications', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.sms_outlined),
                title: const Text('SMS notifications'),
                value: smsNotifications,
                onChanged: (value) async {
                  setSheetState(() => smsNotifications = value);
                  await prefs.setBool('settings_sms_notifications', value);
                },
              ),
              DropdownButtonFormField<String>(
                value: language,
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
                  await prefs.setString('settings_language', value);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security_outlined),
                title: const Text('Account security'),
                subtitle: const Text(
                  'Email, SMS, and Google verification are handled by Supabase.',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInfoSheet(
                    context,
                    'Account security',
                    'Use verified email and phone sign-in for account security. Google sign-in uses Supabase OAuth.',
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
      onTap: () => context.go(RouteNames.saved),
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
