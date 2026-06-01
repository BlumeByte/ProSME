import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import 'jobs_repository.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Center(child: Text('Please sign in to view jobs.'));
    }

    final jobsAsync = ref.watch(jobsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          if (user.role == UserRole.customer)
            IconButton(
              onPressed: () => _openCreateJobSheet(context, ref),
              icon: const Icon(Icons.add),
              tooltip: 'Create job',
            ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Could not load jobs. Check Supabase credentials and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(
              child: Text('No bookings yet. Create your first request.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(jobsStreamProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text('${job.location} • GHS ${job.budget.toStringAsFixed(2)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('${RouteNames.jobDetail}/${job.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: user.role == UserRole.customer
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateJobSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
    );
  }
}

Future<void> _openCreateJobSheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final budgetController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create job', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Description is required'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Location is required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: budgetController,
                  decoration: const InputDecoration(labelText: 'Budget (GHS)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final budget = double.tryParse(value ?? '');
                    if (budget == null || budget <= 0) {
                      return 'Enter a valid budget';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      final user = ref.read(authStateProvider).valueOrNull;
                      if (user == null) {
                        return;
                      }
                      try {
                        await ref.read(jobsRepositoryProvider).createJob(
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              location: locationController.text.trim(),
                              budget: double.parse(budgetController.text),
                              createdBy: user.id,
                            );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Job created successfully.')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create job. Check Supabase setup.'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Create job'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  titleController.dispose();
  descriptionController.dispose();
  locationController.dispose();
  budgetController.dispose();
}
