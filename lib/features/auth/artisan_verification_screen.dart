import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';

class ArtisanVerificationScreen extends StatelessWidget {
  const ArtisanVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artisan verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.verified_user, size: 72),
            const SizedBox(height: 16),
            Text(
              'Upload National ID for verification',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Verification status: Pending',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Submit ID (URL)',
              icon: Icons.upload_file,
              onPressed: () {},
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Continue to dashboard',
              icon: Icons.arrow_forward,
              onPressed: () => context.go(RouteNames.artisanHome),
            ),
          ],
        ),
      ),
    );
  }
}
