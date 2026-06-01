import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/service_providers.dart';
import '../data/supabase_jobs_repository.dart' as data;
import '../data/mock_jobs_repository.dart';
import '../domain/jobs_repository.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  if (!shouldUseSupabase()) {
    return MockJobsRepository();
  }

  return data.SupabaseJobsRepository(ref.watch(supabaseClientProvider));
});

final jobsStreamProvider = StreamProvider<List<JobFeedItem>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchJobs();
});

final jobByIdProvider = Provider.family<JobFeedItem?, String>((ref, id) {
  final jobs = ref.watch(jobsStreamProvider).valueOrNull;

  if (jobs == null) return null;

  return jobs.firstWhere(
    (job) => job.id == id,
    orElse: () => throw Exception('Job not found'),
  );
});
