import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prosme/features/marketplace/jobs/presentation/create_job_form.dart';
import '../applications/jobs_providers.dart';
import 'widgets/create_job_form.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs yet'));
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, i) {
              final job = jobs[i];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          style: const TextStyle(fontSize: 18)),
                      Text('${job.location} • GHS ${job.budget}'),
                      const SizedBox(height: 8),

                      if (job.images.isNotEmpty)
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: job.images
                                .map((img) => Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Image.network(img),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CreateJobForm(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}