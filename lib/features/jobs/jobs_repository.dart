import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/service_providers.dart';

class JobFeedItem {
  const JobFeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.budget,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final double budget;
  final String createdBy;
  final DateTime createdAt;
}

abstract class JobsRepository {
  Stream<List<JobFeedItem>> watchJobs();
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
  });
}

class SupabaseJobsRepository implements JobsRepository {
  SupabaseJobsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<JobFeedItem>> watchJobs() {
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_mapJob).toList(growable: false));
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
  }) async {
    final row = await _client
        .from('jobs')
        .insert({
          'title': title,
          'description': description,
          'location': location,
          'budget': budget,
          'created_by': createdBy,
        })
        .select()
        .single();

    return _mapJob(row);
  }

  JobFeedItem _mapJob(Map<String, dynamic> row) {
    return JobFeedItem(
      id: row['id'].toString(),
      title: (row['title'] as String?) ?? 'Untitled job',
      description: (row['description'] as String?) ?? '',
      location: (row['location'] as String?) ?? 'Unknown location',
      budget: (row['budget'] as num?)?.toDouble() ?? 0,
      createdBy: (row['created_by'] as String?) ?? '',
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class MockJobsRepository implements JobsRepository {
  final _controller = StreamController<List<JobFeedItem>>.broadcast();
  final List<JobFeedItem> _jobs = [];

  @override
  Stream<List<JobFeedItem>> watchJobs() async* {
    yield List<JobFeedItem>.unmodifiable(_jobs);
    yield* _controller.stream;
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
  }) async {
    final job = JobFeedItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      location: location,
      budget: budget,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    _jobs.insert(0, job);
    _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
    return job;
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  if (!shouldUseSupabase()) {
    return MockJobsRepository();
  }
  return SupabaseJobsRepository(ref.watch(supabaseClientProvider));
});

final jobsStreamProvider = StreamProvider<List<JobFeedItem>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchJobs();
});

final jobByIdProvider = Provider.family<JobFeedItem?, String>((ref, id) {
  final jobs = ref.watch(jobsStreamProvider).valueOrNull;
  if (jobs == null) {
    return null;
  }
  for (final job in jobs) {
    if (job.id == id) {
      return job;
    }
  }
  return null;
});
