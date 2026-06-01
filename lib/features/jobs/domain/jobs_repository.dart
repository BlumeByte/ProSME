import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class JobFeedItem {
  JobFeedItem({
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

  Future<void> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
  });
}

class SupabaseJobsRepository implements JobsRepository {
  final _client = Supabase.instance.client;

  @override
  Stream<List<JobFeedItem>> watchJobs() {
    return _client.from('jobs').stream(primaryKey: ['id']).map((rows) {
      final jobs = rows.map(_map).toList();

      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return jobs;
    });
  }

  @override
  Future<void> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final res = await _client.from('jobs').insert({
      'title': title,
      'description': description,
      'location': location,
      'budget': budget,
      'created_by': user.id,
    }).select();

    print("JOB CREATED: $res");
  }

  JobFeedItem _map(Map<String, dynamic> row) {
    return JobFeedItem(
      id: row['id'].toString(),
      title: row['title'] ?? '',
      description: row['description'] ?? '',
      location: row['location'] ?? '',
      budget: (row['budget'] as num?)?.toDouble() ?? 0,
      createdBy: row['created_by'] ?? '',
      createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return SupabaseJobsRepository();
});

final jobsStreamProvider = StreamProvider<List<JobFeedItem>>((ref) {
  return ref.read(jobsRepositoryProvider).watchJobs();
});
