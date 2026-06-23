import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/work_history.dart';

class WorkHistoryService {
  const WorkHistoryService(this._client);

  final SupabaseClient _client;

  Future<WorkHistory> load({
    required String userId,
    required UserRole role,
  }) async {
    final isPlatformRole = role == UserRole.admin || role == UserRole.developer;
    final bidRows = await _loadBidRows(
      userId: userId,
      role: role,
      isPlatformRole: isPlatformRole,
    );
    final bidJobIds = bidRows
        .map((row) => (row['job_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    dynamic requestQuery = _client.from('jobs').select(
          'id,title,location,budget,status,created_by,accepted_amount,created_at',
        );
    if (role == UserRole.customer) {
      requestQuery = requestQuery.eq('created_by', userId);
    } else if (role == UserRole.artisan) {
      if (bidJobIds.isEmpty) {
        return const WorkHistory(bids: [], requests: []);
      }
      requestQuery = requestQuery.inFilter('id', bidJobIds.toList());
    }
    final requestRows = await requestQuery.order(
      'created_at',
      ascending: false,
    );
    final requestList = requestRows as List<dynamic>;
    final requests = requestList
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(_requestFromRow)
        .toList(growable: false);

    final jobsById = <String, Map<String, dynamic>>{
      for (final row in requestList)
        (row['id'] ?? '').toString(): Map<String, dynamic>.from(row as Map),
    };
    final missingJobIds = bidJobIds.difference(jobsById.keys.toSet());
    if (missingJobIds.isNotEmpty) {
      final rows = await _client
          .from('jobs')
          .select('id,title')
          .inFilter('id', missingJobIds.toList());
      for (final row in rows) {
        final value = Map<String, dynamic>.from(row as Map);
        jobsById[(value['id'] ?? '').toString()] = value;
      }
    }

    final artisanIds = bidRows
        .map((row) => (row['artisan_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final artisanNames = <String, String>{};
    if (artisanIds.isNotEmpty) {
      final rows = await _client
          .from('profiles')
          .select('id,username,full_name,email')
          .inFilter('id', artisanIds.toList());
      for (final row in rows) {
        final value = Map<String, dynamic>.from(row as Map);
        artisanNames[(value['id'] ?? '').toString()] = _profileName(value);
      }
    }

    final bids = bidRows.map((row) {
      final jobId = (row['job_id'] ?? '').toString();
      final artisanId = (row['artisan_id'] ?? '').toString();
      return BidHistoryItem(
        id: (row['id'] ?? '').toString(),
        jobId: jobId,
        jobTitle: (jobsById[jobId]?['title'] ?? 'Service request').toString(),
        artisanName: artisanNames[artisanId] ?? 'Artisan',
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        status: (row['status'] ?? 'pending').toString(),
        createdAt: DateTime.tryParse(
              (row['updated_at'] ?? row['created_at'] ?? '').toString(),
            ) ??
            DateTime.now(),
      );
    }).toList(growable: false);

    return WorkHistory(bids: bids, requests: requests);
  }

  Future<List<Map<String, dynamic>>> _loadBidRows({
    required String userId,
    required UserRole role,
    required bool isPlatformRole,
  }) async {
    dynamic query = _client.from('job_bids').select(
          'id,job_id,artisan_id,amount,status,created_at,updated_at',
        );
    if (role == UserRole.artisan) {
      query = query.eq('artisan_id', userId);
    } else if (!isPlatformRole) {
      final jobs =
          await _client.from('jobs').select('id').eq('created_by', userId);
      final jobIds = (jobs as List<dynamic>)
          .map((row) => (row['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (jobIds.isEmpty) return const [];
      query = query.inFilter('job_id', jobIds);
    }
    final rows = await query
        .inFilter('status', const ['accepted', 'rejected']).order('updated_at',
            ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }
}

RequestHistoryItem _requestFromRow(Map<String, dynamic> row) {
  return RequestHistoryItem(
    id: (row['id'] ?? '').toString(),
    title: (row['title'] ?? 'Service request').toString(),
    location: (row['location'] ?? '').toString(),
    status: (row['status'] ?? 'open').toString(),
    budget: (row['budget'] as num?)?.toDouble() ?? 0,
    acceptedAmount: (row['accepted_amount'] as num?)?.toDouble(),
    createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
        DateTime.now(),
  );
}

String _profileName(Map<String, dynamic> row) {
  final fullName = (row['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final username = (row['username'] ?? '').toString().trim();
  if (username.isNotEmpty) return username;
  final email = (row['email'] ?? '').toString().trim();
  return email.isEmpty ? 'Artisan' : email;
}
