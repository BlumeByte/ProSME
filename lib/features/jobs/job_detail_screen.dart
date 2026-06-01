import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import 'jobs_repository.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Could not load this job. Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (jobs) {
          JobFeedItem? job;
          for (final item in jobs) {
            if (item.id == jobId) {
              job = item;
              break;
            }
          }
          if (job == null) {
            return const Center(child: Text('This job is no longer available.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(job.location)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$kCurrencySymbol ${job.budget.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text(job.description),
              const SizedBox(height: 24),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Safety reminder'),
                  subtitle: Text(
                    'Confirm artisan verification status before paying or sharing sensitive information.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
