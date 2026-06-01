import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/applications_repository.dart';
import '../domain/job_application_model.dart';

final applicationsRepositoryProvider = Provider<ApplicationsRepository>((ref) {
  return ApplicationsRepository(Supabase.instance.client);
});

final jobApplicationsProvider =
    StreamProvider.family<List<JobApplication>, String>((ref, jobId) {
  return ref.watch(applicationsRepositoryProvider).watchApplications(jobId);
});
