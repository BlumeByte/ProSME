import 'dart:async';

import 'package:flutter/foundation.dart';
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

class JobBid {
  const JobBid({
    required this.id,
    required this.jobId,
    required this.artisanId,
    required this.amount,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String artisanId;
  final double amount;
  final String message;
  final String status;
  final DateTime createdAt;
}

class JobRating {
  const JobRating({
    required this.id,
    required this.jobId,
    required this.artisanId,
    required this.userId,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String artisanId;
  final String userId;
  final int stars;
  final String comment;
  final DateTime createdAt;
}

abstract class JobsRepository {
  Stream<List<JobFeedItem>> watchJobs();

  Stream<List<JobBid>> watchBids(String jobId);

  Stream<List<JobRating>> watchRatings(String jobId);

  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
  });

  Future<JobBid> createBid({
    required String jobId,
    required String artisanId,
    required double amount,
    required String message,
  });

  Future<void> acceptBid(String bidId);

  Future<JobRating> rateJob({
    required String jobId,
    required String artisanId,
    required String userId,
    required int stars,
    required String comment,
  });
}

class SupabaseJobsRepository implements JobsRepository {
  SupabaseJobsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<JobFeedItem>> watchJobs() async* {
    var lastGood = const <JobFeedItem>[];
    while (true) {
      try {
        final rows = await _client
            .from('jobs')
            .select()
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => _mapJob(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh jobs: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 12));
    }
  }

  @override
  Stream<List<JobRating>> watchRatings(String jobId) async* {
    var lastGood = const <JobRating>[];
    while (true) {
      try {
        final rows = await _client
            .from('job_ratings')
            .select()
            .eq('job_id', jobId)
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => _mapRating(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh job ratings: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 12));
    }
  }

  @override
  Stream<List<JobBid>> watchBids(String jobId) async* {
    var lastGood = const <JobBid>[];
    while (true) {
      try {
        final rows = await _client
            .from('job_bids')
            .select()
            .eq('job_id', jobId)
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => _mapBid(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh job bids: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 8));
    }
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

  @override
  Future<JobBid> createBid({
    required String jobId,
    required String artisanId,
    required double amount,
    required String message,
  }) async {
    final row = await _client
        .from('job_bids')
        .upsert(
          {
            'job_id': jobId,
            'artisan_id': artisanId,
            'amount': amount,
            'message': message,
            'status': 'pending',
          },
          onConflict: 'job_id,artisan_id',
        )
        .select()
        .single();

    return _mapBid(row);
  }

  @override
  Future<void> acceptBid(String bidId) async {
    await _client
        .from('job_bids')
        .update({'status': 'accepted'}).eq('id', bidId);
  }

  @override
  Future<JobRating> rateJob({
    required String jobId,
    required String artisanId,
    required String userId,
    required int stars,
    required String comment,
  }) async {
    final row = await _client
        .from('job_ratings')
        .upsert(
          {
            'job_id': jobId,
            'artisan_id': artisanId,
            'user_id': userId,
            'stars': stars,
            'comment': comment,
          },
          onConflict: 'job_id,user_id',
        )
        .select()
        .single();
    await _client.from('jobs').update({'status': 'completed'}).eq('id', jobId);
    return _mapRating(row);
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

  JobBid _mapBid(Map<String, dynamic> row) {
    return JobBid(
      id: row['id'].toString(),
      jobId: (row['job_id'] as String?) ?? '',
      artisanId: (row['artisan_id'] as String?) ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      message: (row['message'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  JobRating _mapRating(Map<String, dynamic> row) {
    return JobRating(
      id: row['id'].toString(),
      jobId: (row['job_id'] as String?) ?? '',
      artisanId: (row['artisan_id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      stars: (row['stars'] as num?)?.toInt() ?? 0,
      comment: (row['comment'] as String?) ?? '',
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class MockJobsRepository implements JobsRepository {
  final _controller = StreamController<List<JobFeedItem>>.broadcast();
  final Map<String, StreamController<List<JobBid>>> _bidControllers = {};
  final Map<String, StreamController<List<JobRating>>> _ratingControllers = {};
  final List<JobFeedItem> _jobs = [];
  final Map<String, List<JobBid>> _bidsByJobId = {};
  final Map<String, List<JobRating>> _ratingsByJobId = {};

  @override
  Stream<List<JobFeedItem>> watchJobs() async* {
    yield List<JobFeedItem>.unmodifiable(_jobs);
    yield* _controller.stream;
  }

  @override
  Stream<List<JobRating>> watchRatings(String jobId) async* {
    final controller = _ratingControllers.putIfAbsent(
      jobId,
      () => StreamController<List<JobRating>>.broadcast(),
    );
    yield List<JobRating>.unmodifiable(_ratingsByJobId[jobId] ?? const []);
    yield* controller.stream;
  }

  @override
  Stream<List<JobBid>> watchBids(String jobId) async* {
    final controller = _bidControllers.putIfAbsent(
      jobId,
      () => StreamController<List<JobBid>>.broadcast(),
    );
    yield List<JobBid>.unmodifiable(_bidsByJobId[jobId] ?? const []);
    yield* controller.stream;
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

  @override
  Future<JobBid> createBid({
    required String jobId,
    required String artisanId,
    required double amount,
    required String message,
  }) async {
    final bids = _bidsByJobId.putIfAbsent(jobId, () => <JobBid>[]);
    final existingIndex = bids.indexWhere((bid) => bid.artisanId == artisanId);
    final bid = JobBid(
      id: existingIndex == -1
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : bids[existingIndex].id,
      jobId: jobId,
      artisanId: artisanId,
      amount: amount,
      message: message,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    if (existingIndex == -1) {
      bids.insert(0, bid);
    } else {
      bids
        ..removeAt(existingIndex)
        ..insert(0, bid);
    }
    _bidControllers[jobId]?.add(List<JobBid>.unmodifiable(bids));
    return bid;
  }

  @override
  Future<void> acceptBid(String bidId) async {
    for (final entry in _bidsByJobId.entries) {
      final index = entry.value.indexWhere((bid) => bid.id == bidId);
      if (index == -1) continue;
      final bid = entry.value[index];
      entry.value[index] = JobBid(
        id: bid.id,
        jobId: bid.jobId,
        artisanId: bid.artisanId,
        amount: bid.amount,
        message: bid.message,
        status: 'accepted',
        createdAt: bid.createdAt,
      );
      _bidControllers[entry.key]?.add(List<JobBid>.unmodifiable(entry.value));
      return;
    }
  }

  @override
  Future<JobRating> rateJob({
    required String jobId,
    required String artisanId,
    required String userId,
    required int stars,
    required String comment,
  }) async {
    final ratings = _ratingsByJobId.putIfAbsent(jobId, () => <JobRating>[]);
    final existingIndex =
        ratings.indexWhere((rating) => rating.userId == userId);
    final rating = JobRating(
      id: existingIndex == -1
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : ratings[existingIndex].id,
      jobId: jobId,
      artisanId: artisanId,
      userId: userId,
      stars: stars,
      comment: comment,
      createdAt: DateTime.now(),
    );
    if (existingIndex == -1) {
      ratings.insert(0, rating);
    } else {
      ratings
        ..removeAt(existingIndex)
        ..insert(0, rating);
    }
    _ratingControllers[jobId]?.add(List<JobRating>.unmodifiable(ratings));
    return rating;
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

final jobBidsProvider =
    StreamProvider.family<List<JobBid>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).watchBids(jobId);
});

final jobRatingsProvider =
    StreamProvider.family<List<JobRating>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).watchRatings(jobId);
});
