import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../routes/route_names.dart';
import '../jobs/jobs_repository.dart';
import '../../services/service_providers.dart';

class UploadRequestScreen extends ConsumerStatefulWidget {
  const UploadRequestScreen({super.key});

  @override
  ConsumerState<UploadRequestScreen> createState() => _UploadRequestScreenState();
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
      await ref.read(jobsRepositoryProvider).createJob(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim(),
            budget: double.parse(_budgetController.text.trim()),
            createdBy: user.id,
          );
      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _budgetController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request uploaded successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => context.go(RouteNames.auth),
          icon: const Icon(Icons.login),
          label: const Text('Sign in to upload requests'),
        ),
      );
    }

    final jobs = ref.watch(jobsStreamProvider).valueOrNull ?? const <JobFeedItem>[];
    final myUploads = jobs.where((job) => job.createdBy == user.id).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Upload service request', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Service title'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Describe your need'),
                minLines: 3,
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Budget ($kCurrencySymbol)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final budget = double.tryParse((value ?? '').trim());
                  if (budget == null || budget <= 0) return 'Enter a valid budget';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Uploading...' : 'Upload'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('My uploaded requests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (myUploads.isEmpty)
          const Text('No uploads yet.')
        else
          ...myUploads.map(
            (job) => Card(
              child: ListTile(
                title: Text(job.title),
                subtitle: Text('${job.location} • GHS ${job.budget.toStringAsFixed(2)}'),
              ),
            ),
          ),
      ],
    );
  }
}
