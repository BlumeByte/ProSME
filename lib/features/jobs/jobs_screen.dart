import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/mock_data.dart';
import '../../routes/route_names.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _JobList(status: 'Active', onTap: (id) {
                  context.go('${RouteNames.jobDetail}/$id');
                }),
                _JobList(status: 'Completed', onTap: (id) {}),
                _JobList(status: 'Cancelled', onTap: (id) {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.status, required this.onTap});

  final String status;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    final jobs = demoJobs;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return ListTile(
          leading: const Icon(Icons.work_outline),
          title: Text('Job ${job.id}'),
          subtitle: Text('ETA: ${job.eta}'),
          trailing: Text(status),
          onTap: () => onTap(job.id),
        );
      },
    );
  }
}
