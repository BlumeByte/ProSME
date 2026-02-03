import 'package:flutter/material.dart';
import '../../core/utils/mock_data.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final job = demoJobs.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Job detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Job ${job.id}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Meeting: ${job.meetingType}'),
          const SizedBox(height: 8),
          Text('ETA: ${job.eta}'),
          const SizedBox(height: 16),
          Text('Progress',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...job.progress.map(
            (item) => ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item.title),
              subtitle: Text(item.detail),
            ),
          ),
        ],
      ),
    );
  }
}
