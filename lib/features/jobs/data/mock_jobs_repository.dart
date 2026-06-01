import 'dart:async';
import '../domain/jobs_repository.dart';

class MockJobsRepository implements JobsRepository {
  final List<JobFeedItem> _jobs = [];
  final _controller = StreamController<List<JobFeedItem>>.broadcast();

  @override
  Stream<List<JobFeedItem>> watchJobs() async* {
    yield _jobs;
    yield* _controller.stream;
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
  }) async {
    final job = JobFeedItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      location: location,
      budget: budget,
      createdBy: 'mock-user-id',
      createdAt: DateTime.now(),
    );

    _jobs.insert(0, job);
    _controller.add(List.unmodifiable(_jobs));

    return job;
  }
}
