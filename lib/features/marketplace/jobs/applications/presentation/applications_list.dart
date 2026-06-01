import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/applications_providers.dart';

class ApplicationsList extends ConsumerWidget {
  const ApplicationsList({
    super.key,
    required this.jobId,
    required this.isJobOwner,
  });

  final String jobId;
  final bool isJobOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(jobApplicationsProvider(jobId));

    return applicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Applications error: $error'),
      data: (applications) {
        if (applications.isEmpty) {
          return const Text('No applications yet');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: applications.map((application) {
            return Card(
              child: ListTile(
                title:
                    Text('GHS ${application.proposedPrice.toStringAsFixed(2)}'),
                subtitle: Text(
                  '${application.message}\nStatus: ${application.status}',
                ),
                isThreeLine: true,
                trailing: isJobOwner && application.status == 'pending'
                    ? Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () {
                              ref
                                  .read(applicationsRepositoryProvider)
                                  .acceptApplication(
                                    applicationId: application.id,
                                    jobId: application.jobId,
                                    artisanId: application.artisanId,
                                  );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              ref
                                  .read(applicationsRepositoryProvider)
                                  .rejectApplication(application.id);
                            },
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
