import 'package:flutter/material.dart';
import 'package:prosme/features/jobs/domain/jobs_repository.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job});

  final JobFeedItem job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text("Location: ${job.location}"),
            const SizedBox(height: 10),
            Text("Budget: GHS ${job.budget}"),
            const SizedBox(height: 20),
            Text(job.description),
          ],
        ),
      ),
    );
  }
}
