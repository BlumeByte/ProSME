import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/constants.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(
    WidgetRef ref,
    BuildContext context,
    UserRole role,
  ) async {
    final authService = ref.read(authServiceProvider);
    await authService.updateRole(role);
    if (role == UserRole.artisan) {
      context.go(RouteNames.artisanVerification);
    } else if (role == UserRole.admin) {
      context.go(RouteNames.adminHome);
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'I need a service',
              icon: Icons.person,
              onPressed: () => _selectRole(ref, context, UserRole.customer),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'I am an artisan',
              icon: Icons.handyman,
              onPressed: () => _selectRole(ref, context, UserRole.artisan),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Admin access',
              icon: Icons.admin_panel_settings,
              onPressed: () => _selectRole(ref, context, UserRole.admin),
            ),
          ],
        ),
      ),
    );
  }
}
