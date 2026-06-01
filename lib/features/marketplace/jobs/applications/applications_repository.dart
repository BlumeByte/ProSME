import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/job_application_model.dart';

class ApplicationsRepository {
  ApplicationsRepository(this._client);

  final SupabaseClient _client;

  Future<void> applyToJob({
    required String jobId,
    required String message,
    required double proposedPrice,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await _client.from('job_applications').insert({
      'job_id': jobId,
      'artisan_id': user.id,
      'message': message,
      'proposed_price': proposedPrice,
      'status': 'pending',
    });
  }

  Stream<List<JobApplication>> watchApplications(String jobId) {
    return _client
        .from('job_applications')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .map((rows) {
          final applications = rows.map(_mapApplication).toList();

          applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return applications;
        });
  }

  Future<void> acceptApplication({
    required String applicationId,
    required String jobId,
    required String artisanId,
  }) async {
    await _client.from('job_applications').update({
      'status': 'accepted',
    }).eq('id', applicationId);

    await _client
        .from('job_applications')
        .update({
          'status': 'rejected',
        })
        .eq('job_id', jobId)
        .neq('id', applicationId);

    await _client.from('jobs').update({
      'status': 'assigned',
      'assigned_to': artisanId,
    }).eq('id', jobId);
  }

  Future<void> rejectApplication(String applicationId) async {
    await _client.from('job_applications').update({
      'status': 'rejected',
    }).eq('id', applicationId);
  }

  JobApplication _mapApplication(Map<String, dynamic> row) {
    return JobApplication(
      id: row['id'].toString(),
      jobId: row['job_id'].toString(),
      artisanId: row['artisan_id'].toString(),
      message: row['message'] ?? '',
      proposedPrice: (row['proposed_price'] as num?)?.toDouble() ?? 0,
      status: row['status'] ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
