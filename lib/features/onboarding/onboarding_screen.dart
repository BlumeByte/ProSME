import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/app_launch_service.dart';
import '../../services/app_settings_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/prosme_logo.png',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                settings.t('Find trusted artisans fast'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                settings.t('Simple, icon-driven steps for customers and SMEs.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: settings.t('Get Started'),
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
                child: Text(settings.t('Sign in / Sign up')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
