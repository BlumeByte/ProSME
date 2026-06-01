import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/jobs_repository.dart'; // JobFeedItem is already defined here

class SupabaseJobsRepository implements JobsRepository {
  SupabaseJobsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<JobFeedItem>> watchJobs() {
    return _client.from('jobs').stream(primaryKey: ['id']).map<List<JobFeedItem>>((rows) {
      final jobs = rows.map(_mapJob).toList();

      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return jobs;
    });
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
  }) async {
    final row = await _client
        .from('jobs')
        .insert({
          'title': title,
          'description': description,
          'location': location,
          'budget': budget,
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();

    return _mapJob(row);
  }

  JobFeedItem _mapJob(Map<String, dynamic> row) {
    return JobFeedItem(
      id: row['id'].toString(),
      title: row['title'] ?? 'Untitled job',
      description: row['description'] ?? '',
      location: row['location'] ?? '',
      budget: (row['budget'] as num).toDouble(),
      createdBy: row['created_by'] ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
