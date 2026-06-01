import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../applications/presentation/apply_to_job_sheet.dart';
import '../../applications/presentation/applications_list.dart';
import '../application/jobs_providers.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (jobs) {
          final job = jobs.where((item) => item.id == jobId).firstOrNull;

          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          final isOwner = currentUser?.id == job.createdBy;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Status: ${job.status}'),
              Text('Location: ${job.location}'),
              Text('Budget: GHS ${job.budget.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              if (job.images.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: job.images.map((imageUrl) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.network(
                          imageUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              Text(job.description),
              const SizedBox(height: 24),
              if (!isOwner && job.status == 'open')
                FilledButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ApplyToJobSheet(jobId: job.id),
                    );
                  },
                  child: const Text('Apply to this job'),
                ),
              const SizedBox(height: 24),
              if (isOwner) ...[
                Text(
                  'Applications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ApplicationsList(
                  jobId: job.id,
                  isJobOwner: isOwner,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
