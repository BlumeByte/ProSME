import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class ArtisanVerificationScreen extends ConsumerStatefulWidget {
  const ArtisanVerificationScreen({super.key});

  @override
  ConsumerState<ArtisanVerificationScreen> createState() =>
      _ArtisanVerificationScreenState();
}

class _ArtisanVerificationScreenState
    extends ConsumerState<ArtisanVerificationScreen> {
  final _idUrlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final nationalIdUrl = _idUrlController.text.trim();
    if (user == null) {
      context.go(RouteNames.auth);
      return;
    }
    if (nationalIdUrl.isEmpty || !Uri.parse(nationalIdUrl).hasAbsolutePath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a valid National ID file URL.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminServiceProvider).submitArtisanVerification(
            userId: user.id,
            nationalIdUrl: nationalIdUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification sent to admin for review.'),
        ),
      );
      context.go(RouteNames.artisanHome);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit verification. Check Supabase setup.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artisan verification')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.verified_user, size: 72),
          const SizedBox(height: 16),
          Text(
            'Upload National ID for verification',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Paste the uploaded file URL. Admin will review it and verified artisans get a public checkmark.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _idUrlController,
            decoration: const InputDecoration(
              labelText: 'National ID file URL',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _isSubmitting ? 'Submitting...' : 'Submit for review',
            icon: Icons.upload_file,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(RouteNames.artisanHome),
            child: const Text('Continue to dashboard'),
          ),
        ],
      ),
    );
  }
}
