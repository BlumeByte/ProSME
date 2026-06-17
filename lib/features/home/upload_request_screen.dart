import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/currency.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../jobs/jobs_repository.dart';

class UploadRequestScreen extends ConsumerStatefulWidget {
  const UploadRequestScreen({super.key});

  @override
  ConsumerState<UploadRequestScreen> createState() =>
      _UploadRequestScreenState();
}

class _UploadRequestScreenState extends ConsumerState<UploadRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (mounted) {
        context.go(RouteNames.auth);
      }
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final settings = ref.read(appSettingsControllerProvider);
      final currencyCode = settings.currencyCode;
      await ref.read(jobsRepositoryProvider).createJob(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim(),
            budget: convertToGhs(
              double.parse(_budgetController.text.trim()),
              currencyCode,
            ),
            createdBy: user.id,
          );
      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _budgetController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Request uploaded successfully.'))),
      );
    } catch (_) {
      if (!mounted) return;
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t('Could not upload request. Check Supabase setup.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final currencyCode = settings.currencyCode;
    if (user == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => context.go(RouteNames.auth),
          icon: const Icon(Icons.login),
          label: Text(settings.t('Sign in to upload requests')),
        ),
      );
    }

    final jobsAsync = ref.watch(jobsStreamProvider);
    final jobs = jobsAsync.valueOrNull ?? const <JobFeedItem>[];
    final myUploads =
        jobs.where((job) => job.createdBy == user.id).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(settings.t('Upload service request'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: settings.t('Service title'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? settings.t('Title is required')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: settings.t('Describe your need'),
                ),
                minLines: 3,
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? settings.t('Description is required')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: settings.t('Location')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? settings.t('Location is required')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _budgetController,
                decoration: InputDecoration(
                  labelText: '${settings.t('Budget')} ($currencyCode)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final budget = double.tryParse((value ?? '').trim());
                  if (budget == null || budget <= 0) {
                    return settings.t('Enter a valid budget');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    settings.t(_isSubmitting ? 'Uploading...' : 'Upload'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(settings.t('My uploaded requests'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (jobsAsync.hasError)
          Text(settings.t(
              'Could not load uploads. Check Supabase credentials and try again.'))
        else if (myUploads.isEmpty)
          Text(settings.t('No uploads yet.'))
        else
          ...myUploads.map(
            (job) => Card(
              child: ListTile(
                title: Text(job.title),
                subtitle: Text(
                  '${job.location} - ${formatMoney(job.budget, currencyCode)}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
