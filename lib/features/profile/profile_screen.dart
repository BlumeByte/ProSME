import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/service_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final authService = ref.read(authServiceProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: CircleAvatar(
            child: user?.photoUrl.isNotEmpty == true
                ? ClipOval(
                    child: Image.network(
                      user!.photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person),
                    ),
                  )
                : const Icon(Icons.person),
          ),
          title: Text(user?.name ?? 'Guest'),
          subtitle: Text(user?.phone ?? ''),
        ),
        const Divider(),
        if (user == null)
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sign in to continue'),
            onTap: () => context.go(RouteNames.auth),
          ),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Change username'),
            subtitle: Text(user.name),
            onTap: () => _showChangeUsernameDialog(context, authService, user.name),
          ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          subtitle: const Text('English / Twi / Ewe'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text('Help & Support'),
          onTap: () => context.go(RouteNames.aiSupport),
        ),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => authService.signOut(),
          ),
        if (user != null)
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
