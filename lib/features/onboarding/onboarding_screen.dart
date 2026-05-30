import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/app_launch_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.handyman, size: 96),
              const SizedBox(height: 24),
              Text(
                'Find trusted artisans fast',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Simple, icon-driven steps for customers and SMEs.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Get Started',
                icon: Icons.arrow_forward,
                onPressed: () async {
                  await AppLaunchService.markWelcomeSeen();
                  if (context.mounted) {
                    context.go(RouteNames.home);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await AppLaunchService.markWelcomeSeen();
                  if (context.mounted) {
                    context.go(RouteNames.auth);
                  }
                },
                child: const Text('Sign in / Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
