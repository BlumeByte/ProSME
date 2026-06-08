import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/constants.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/safe_back_button.dart';
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
    if (!context.mounted) return;
    if (role == UserRole.artisan) {
      context.go(RouteNames.artisanVerification);
    } else if (role == UserRole.developer) {
      context.go(RouteNames.adminHome);
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Choose role'),
      ),
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
          ],
        ),
      ),
    );
  }
}
