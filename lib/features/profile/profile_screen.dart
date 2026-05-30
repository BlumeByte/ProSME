import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
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
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () => ref.read(authServiceProvider).signOut(),
        ),
      ],
    );
  }
}
