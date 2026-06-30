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
    this.images = const [],
    this.status = 'open',
    this.locationLat,
    this.locationLng,
    this.locationSource = 'typed',
    this.workStatus = 'open',
    this.acceptedAmount,
    this.etaAt,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final double budget;
  final String createdBy;
  final DateTime createdAt;
  final List<String> images;
  final String status;
  final double? locationLat;
  final double? locationLng;
  final String locationSource;
  final String workStatus;
  final double? acceptedAmount;
  final DateTime? etaAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

class JobProgressEvent {
  const JobProgressEvent({
    required this.id,
    required this.jobId,
    required this.actorId,
    required this.status,
    required this.note,
    required this.etaAt,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String actorId;
  final String status;
  final String note;
  final DateTime? etaAt;
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
    this.artisanName,
    this.artisanAvatarUrl,
    this.artisanVerified = false,
    this.acceptedBidCount = 0,
  });

  final String id;
  final String jobId;
  final String artisanId;
  final double amount;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? artisanName;
  final String? artisanAvatarUrl;
  final bool artisanVerified;
  final int acceptedBidCount;
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

  Stream<List<JobBid>> watchBidsByArtisan(String artisanId);

  Stream<List<JobRating>> watchRatings(String jobId);

  Stream<List<JobRating>> watchRatingsByArtisan(String artisanId);

  Stream<List<JobProgressEvent>> watchProgress(String jobId);

  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  });

  Future<JobFeedItem> updateJob({
    required String jobId,
    required String title,
    required String description,
    required String location,
    required double budget,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  });

  Future<void> deleteJob(String jobId);

  Future<JobBid> createBid({
    required String jobId,
    required String artisanId,
    required double amount,
    required String message,
  });

  Future<void> acceptBid(String bidId);

  Future<void> updateProgress({
    required String jobId,
    required String status,
    DateTime? etaAt,
    String note = '',
  });

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
            .neq('status', 'cancelled')
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
  Stream<List<JobProgressEvent>> watchProgress(String jobId) async* {
    var lastGood = const <JobProgressEvent>[];
    while (true) {
      try {
        final rows = await _client
            .from('job_status_events')
            .select()
            .eq('job_id', jobId)
            .order('created_at');
        lastGood = rows
            .map((row) => _mapProgress(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh job progress: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 10));
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
  Stream<List<JobRating>> watchRatingsByArtisan(String artisanId) async* {
    var lastGood = const <JobRating>[];
    while (true) {
      try {
        final rows = await _client
            .from('job_ratings')
            .select()
            .eq('artisan_id', artisanId)
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => _mapRating(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh artisan ratings: $error');
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
        lastGood = await _hydrateBids(rows
            .map((row) => _mapBid(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false));
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
  Stream<List<JobBid>> watchBidsByArtisan(String artisanId) async* {
    var lastGood = const <JobBid>[];
    while (true) {
      try {
        final rows = await _client
            .from('job_bids')
            .select()
            .eq('artisan_id', artisanId)
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => _mapBid(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh artisan bids: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  Future<List<JobBid>> _hydrateBids(List<JobBid> bids) async {
    if (bids.isEmpty) return bids;
    final artisanIds = bids.map((bid) => bid.artisanId).toSet().toList();
    try {
      final profileRows = await _client
          .from('profiles')
          .select('id,username,full_name,avatar_url,verification_status')
          .inFilter('id', artisanIds);
      final acceptedRows = await _client
          .from('job_bids')
          .select('artisan_id')
          .inFilter('artisan_id', artisanIds)
          .eq('status', 'accepted');

      final profiles = <String, Map<String, dynamic>>{};
      for (final row in profileRows) {
        final profile = Map<String, dynamic>.from(row as Map);
        profiles[(profile['id'] ?? '').toString()] = profile;
      }

      final acceptedCounts = <String, int>{};
      for (final row in acceptedRows) {
        final artisanId = (row['artisan_id'] ?? '').toString();
        acceptedCounts.update(artisanId, (value) => value + 1,
            ifAbsent: () => 1);
      }

      return bids.map((bid) {
        final profile = profiles[bid.artisanId];
        final name = (profile?['full_name'] ?? profile?['username'] ?? '')
            .toString()
            .trim();
        return JobBid(
          id: bid.id,
          jobId: bid.jobId,
          artisanId: bid.artisanId,
          amount: bid.amount,
          message: bid.message,
          status: bid.status,
          createdAt: bid.createdAt,
          artisanName: name.isEmpty ? null : name,
          artisanAvatarUrl: (profile?['avatar_url'] ?? '').toString(),
          artisanVerified:
              (profile?['verification_status'] ?? '').toString() == 'verified',
          acceptedBidCount: acceptedCounts[bid.artisanId] ?? 0,
        );
      }).toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate bid profiles: $error');
      debugPrintStack(stackTrace: stackTrace);
      return bids;
    }
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  }) async {
    final row = await _client
        .from('jobs')
        .insert({
          'title': title,
          'description': description,
          'location': location,
          'budget': budget,
          'created_by': createdBy,
          'images': images,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'location_source': locationSource,
        })
        .select()
        .single();

    return _mapJob(row);
  }

  @override
  Future<JobFeedItem> updateJob({
    required String jobId,
    required String title,
    required String description,
    required String location,
    required double budget,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  }) async {
    final row = await _client
        .from('jobs')
        .update({
          'title': title,
          'description': description,
          'location': location,
          'budget': budget,
          'images': images,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'location_source': locationSource,
        })
        .eq('id', jobId)
        .select()
        .single();

    return _mapJob(row);
  }

  @override
  Future<void> deleteJob(String jobId) async {
    await _client.from('jobs').delete().eq('id', jobId);
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
        .update({'status': 'accepted'})
        .eq('id', bidId)
        .select('id')
        .single();
  }

  @override
  Future<void> updateProgress({
    required String jobId,
    required String status,
    DateTime? etaAt,
    String note = '',
  }) async {
    await _client.rpc('update_job_progress', params: {
      'p_job_id': jobId,
      'p_status': status,
      'p_eta_at': etaAt?.toUtc().toIso8601String(),
      'p_note': note,
    });
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
      status: (row['status'] as String?) ?? 'open',
      locationLat: (row['location_lat'] as num?)?.toDouble(),
      locationLng: (row['location_lng'] as num?)?.toDouble(),
      locationSource: (row['location_source'] as String?) ?? 'typed',
      workStatus: (row['work_status'] as String?) ??
          ((row['accepted_bid_id'] ?? '').toString().isEmpty
              ? 'open'
              : (row['status'] == 'completed' ? 'completed' : 'accepted')),
      acceptedAmount: (row['accepted_amount'] as num?)?.toDouble(),
      etaAt: DateTime.tryParse((row['eta_at'] ?? '').toString()),
      startedAt: DateTime.tryParse((row['started_at'] ?? '').toString()),
      completedAt: DateTime.tryParse((row['completed_at'] ?? '').toString()),
      images: List<String>.from(
        (row['images'] ?? const <dynamic>[]) as List<dynamic>,
      ),
    );
  }

  JobProgressEvent _mapProgress(Map<String, dynamic> row) {
    return JobProgressEvent(
      id: (row['id'] ?? '').toString(),
      jobId: (row['job_id'] ?? '').toString(),
      actorId: (row['actor_id'] ?? '').toString(),
      status: (row['status'] ?? 'accepted').toString(),
      note: (row['note'] ?? '').toString(),
      etaAt: DateTime.tryParse((row['eta_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
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
  final Map<String, List<JobProgressEvent>> _progressByJobId = {};
  final Map<String, StreamController<List<JobProgressEvent>>>
      _progressControllers = {};

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
  Stream<List<JobRating>> watchRatingsByArtisan(String artisanId) async* {
    final ratings = _ratingsByJobId.values
        .expand((items) => items)
        .where((rating) => rating.artisanId == artisanId)
        .toList(growable: false);
    yield List<JobRating>.unmodifiable(ratings);
  }

  @override
  Stream<List<JobProgressEvent>> watchProgress(String jobId) async* {
    final controller = _progressControllers.putIfAbsent(
      jobId,
      () => StreamController<List<JobProgressEvent>>.broadcast(),
    );
    yield List<JobProgressEvent>.unmodifiable(
      _progressByJobId[jobId] ?? const [],
    );
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
  Stream<List<JobBid>> watchBidsByArtisan(String artisanId) async* {
    final owned = _bidsByJobId.values
        .expand((bids) => bids)
        .where((bid) => bid.artisanId == artisanId)
        .toList(growable: false);
    yield List<JobBid>.unmodifiable(owned);
  }

  @override
  Future<JobFeedItem> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required String createdBy,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  }) async {
    final job = JobFeedItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      location: location,
      budget: budget,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      images: images,
      status: 'open',
      locationLat: locationLat,
      locationLng: locationLng,
      locationSource: locationSource,
      workStatus: 'open',
      acceptedAmount: null,
    );
    _jobs.insert(0, job);
    _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
    return job;
  }

  @override
  Future<JobFeedItem> updateJob({
    required String jobId,
    required String title,
    required String description,
    required String location,
    required double budget,
    List<String> images = const [],
    double? locationLat,
    double? locationLng,
    String locationSource = 'typed',
  }) async {
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index == -1) {
      return createJob(
        title: title,
        description: description,
        location: location,
        budget: budget,
        createdBy: '',
        images: images,
        locationLat: locationLat,
        locationLng: locationLng,
        locationSource: locationSource,
      );
    }
    final current = _jobs[index];
    final updated = JobFeedItem(
      id: current.id,
      title: title,
      description: description,
      location: location,
      budget: budget,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      images: images,
      status: current.status,
      locationLat: locationLat,
      locationLng: locationLng,
      locationSource: locationSource,
      workStatus: current.workStatus,
      acceptedAmount: current.acceptedAmount,
      etaAt: current.etaAt,
      startedAt: current.startedAt,
      completedAt: current.completedAt,
    );
    _jobs[index] = updated;
    _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
    return updated;
  }

  @override
  Future<void> deleteJob(String jobId) async {
    _jobs.removeWhere((job) => job.id == jobId);
    _bidsByJobId.remove(jobId);
    _ratingsByJobId.remove(jobId);
    _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
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
        artisanName: bid.artisanName,
        artisanAvatarUrl: bid.artisanAvatarUrl,
        artisanVerified: bid.artisanVerified,
        acceptedBidCount: bid.acceptedBidCount + 1,
      );
      _bidControllers[entry.key]?.add(List<JobBid>.unmodifiable(entry.value));
      final jobIndex = _jobs.indexWhere((job) => job.id == bid.jobId);
      if (jobIndex != -1) {
        final job = _jobs[jobIndex];
        _jobs[jobIndex] = _copyJobWithProgress(
          job,
          status: 'accepted',
          acceptedAmount: bid.amount,
        );
      }
      final event = JobProgressEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        jobId: bid.jobId,
        actorId: '',
        status: 'accepted',
        note: 'Bid accepted',
        etaAt: null,
        createdAt: DateTime.now(),
      );
      _progressByJobId.putIfAbsent(bid.jobId, () => []).add(event);
      _progressControllers[bid.jobId]
          ?.add(List.unmodifiable(_progressByJobId[bid.jobId]!));
      _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
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

  @override
  Future<void> updateProgress({
    required String jobId,
    required String status,
    DateTime? etaAt,
    String note = '',
  }) async {
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index != -1) {
      _jobs[index] = _copyJobWithProgress(
        _jobs[index],
        status: status,
        etaAt: etaAt,
      );
      _controller.add(List<JobFeedItem>.unmodifiable(_jobs));
    }
    final event = JobProgressEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      jobId: jobId,
      actorId: '',
      status: status,
      note: note,
      etaAt: etaAt,
      createdAt: DateTime.now(),
    );
    _progressByJobId.putIfAbsent(jobId, () => []).add(event);
    _progressControllers[jobId]
        ?.add(List.unmodifiable(_progressByJobId[jobId]!));
  }
}

JobFeedItem _copyJobWithProgress(
  JobFeedItem job, {
  required String status,
  DateTime? etaAt,
  double? acceptedAmount,
}) {
  final now = DateTime.now();
  return JobFeedItem(
    id: job.id,
    title: job.title,
    description: job.description,
    location: job.location,
    budget: job.budget,
    createdBy: job.createdBy,
    createdAt: job.createdAt,
    images: job.images,
    status: status == 'completed' ? 'completed' : job.status,
    locationLat: job.locationLat,
    locationLng: job.locationLng,
    locationSource: job.locationSource,
    workStatus: status,
    acceptedAmount: acceptedAmount ?? job.acceptedAmount,
    etaAt: etaAt ?? job.etaAt,
    startedAt: status == 'in_progress' ? job.startedAt ?? now : job.startedAt,
    completedAt:
        status == 'completed' ? job.completedAt ?? now : job.completedAt,
  );
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

final artisanBidsProvider =
    StreamProvider.family<List<JobBid>, String>((ref, artisanId) {
  return ref.watch(jobsRepositoryProvider).watchBidsByArtisan(artisanId);
});

final jobRatingsProvider =
    StreamProvider.family<List<JobRating>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).watchRatings(jobId);
});

final artisanRatingsProvider =
    StreamProvider.family<List<JobRating>, String>((ref, artisanId) {
  return ref.watch(jobsRepositoryProvider).watchRatingsByArtisan(artisanId);
});

final jobProgressProvider =
    StreamProvider.family<List<JobProgressEvent>, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).watchProgress(jobId);
});
