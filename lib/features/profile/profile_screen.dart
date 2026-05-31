import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String _paymentMethod = 'Cash';

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

    final firstName = user.name.trim().split(' ').first;

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
        _SectionTitle(title: 'Favourites'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No favourites added',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Save all your favourites in one place using the heart icon.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.favorite, color: Colors.white),
              ),
            ],
          ),
        ),
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
        _SettingsTile(icon: Icons.account_balance_wallet_outlined, title: 'ProSME Balance'),
        const SizedBox(height: 26),
        _SectionTitle(title: 'Profile'),
        const SizedBox(height: 8),
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
        _SectionTitle(title: 'Other'),
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
          onTap: () => _showInfoSheet(context, 'Settings', 'Settings are managed in this tab.'),
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
            'About ProSME',
            'ProSME helps customers connect with verified SMEs and artisans.',
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
  }
}

Future<void> _showChangeUsernameDialog(
  BuildContext context,
  AuthService authService,
  String currentUsername,
) async {
  final controller = TextEditingController(text: currentUsername);
  final nextUsername = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change username'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter new username',
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
  );
  controller.dispose();

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
