import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class SafeBackButton extends ConsumerWidget {
  const SafeBackButton({
    super.key,
    this.fallbackRoute = RouteNames.home,
  });

  final String fallbackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
        final user = ref.read(authStateProvider).valueOrNull;
        if (fallbackRoute == RouteNames.home &&
            user?.role == UserRole.artisan) {
          context.go(RouteNames.artisanHome);
          return;
        }
        context.go(fallbackRoute);
      },
    );
  }
}
