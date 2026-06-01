import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prosme/features/jobs/application/jobs_providers.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jobs Dashboard')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs found'));
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];

              return ListTile(
                title: Text(job.title),
                subtitle: Text('${job.location} • GHS ${job.budget}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(jobsRepositoryProvider).createJob(
                title: "Test Job",
                description: "Auto created",
                location: "Accra",
                budget: 100,
              );

          ref.invalidate(jobsStreamProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
