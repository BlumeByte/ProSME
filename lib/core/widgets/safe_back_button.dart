import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';

class SafeBackButton extends StatelessWidget {
  const SafeBackButton({
    super.key,
    this.fallbackRoute = RouteNames.home,
  });

  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
        context.go(fallbackRoute);
      },
    );
  }
}
