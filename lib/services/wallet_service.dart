import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/wallet_transaction.dart';
import 'service_providers.dart';

class WalletService {
  const WalletService(this._client);

  final SupabaseClient _client;

  Future<List<WalletTransaction>> loadTransactions({
    required String userId,
    required UserRole role,
  }) async {
    if (!shouldUseSupabase()) return const [];

    try {
      dynamic query = _client.from('wallet_transactions').select();
      if (role != UserRole.admin && role != UserRole.developer) {
        query = query.or('user_id.eq.$userId,artisan_id.eq.$userId');
      }
      final List<dynamic> rows =
          await query.order('created_at', ascending: false) as List<dynamic>;
      final List<WalletTransaction> items = rows
          .map<WalletTransaction>((row) => WalletTransaction.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList(growable: false);
      return _hydrateLegacyRows(items);
    } on PostgrestException catch (error) {
      if (!_canUseBidFallback(error)) rethrow;
      return _loadAcceptedBidFallback(userId: userId, role: role);
    }
  }

  bool _canUseBidFallback(PostgrestException error) {
    const recoverableCodes = {
      '42P01',
      '42703',
      '42501',
      'PGRST204',
      'PGRST205',
    };
    if (recoverableCodes.contains(error.code)) return true;
    final message = '${error.message} ${error.details}'.toLowerCase();
    return message.contains('wallet_transactions') ||
        message.contains('wallet transaction');
  }

  Future<List<WalletTransaction>> _loadAcceptedBidFallback({
    required String userId,
    required UserRole role,
  }) async {
    final platformRole = role == UserRole.admin || role == UserRole.developer;
    final jobs = <String, Map<String, dynamic>>{};

    if (role == UserRole.customer || platformRole) {
      dynamic jobsQuery =
          _client.from('jobs').select('id,title,location,created_by,status');
      if (!platformRole) jobsQuery = jobsQuery.eq('created_by', userId);
      final jobRows = await jobsQuery;
      for (final row in jobRows) {
        final value = Map<String, dynamic>.from(row as Map);
        jobs[(value['id'] ?? '').toString()] = value;
      }
    }

    dynamic bidsQuery = _client
        .from('job_bids')
        .select('id,job_id,artisan_id,amount,status,created_at,updated_at')
        .eq('status', 'accepted');
    if (role == UserRole.artisan) {
      bidsQuery = bidsQuery.eq('artisan_id', userId);
    } else if (!platformRole) {
      if (jobs.isEmpty) return const [];
      bidsQuery = bidsQuery.inFilter('job_id', jobs.keys.toList());
    }
    final List<dynamic> bidRows =
        await bidsQuery.order('updated_at', ascending: false) as List<dynamic>;

    if (role == UserRole.artisan && bidRows.isNotEmpty) {
      final jobIds = bidRows
          .map((row) => (row['job_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final jobRows = await _client
          .from('jobs')
          .select('id,title,location,created_by,status')
          .inFilter('id', jobIds);
      for (final row in jobRows) {
        final value = Map<String, dynamic>.from(row as Map);
        jobs[(value['id'] ?? '').toString()] = value;
      }
    }

    final List<WalletTransaction> items = bidRows.map<WalletTransaction>((row) {
      final value = Map<String, dynamic>.from(row as Map);
      final bidId = (value['id'] ?? '').toString();
      final jobId = (value['job_id'] ?? '').toString();
      final job = jobs[jobId];
      return WalletTransaction(
        id: 'accepted-$bidId',
        jobId: jobId,
        bidId: bidId,
        customerId: (job?['created_by'] ?? '').toString(),
        artisanId: (value['artisan_id'] ?? '').toString(),
        amount: (value['amount'] as num?)?.toDouble() ?? 0,
        currency: 'GHS',
        eventType: 'bid_accepted',
        invoiceNumber: 'PSME-${_shortId(bidId)}',
        jobTitle: (job?['title'] ?? '').toString(),
        jobLocation: (job?['location'] ?? '').toString(),
        customerName: '',
        customerEmail: '',
        artisanName: '',
        artisanEmail: '',
        paymentStatus: 'agreed',
        workStatus: (job?['status'] ?? '').toString() == 'completed'
            ? 'completed'
            : 'accepted',
        completedAt: null,
        createdAt: DateTime.tryParse(
              (value['updated_at'] ?? value['created_at'] ?? '').toString(),
            ) ??
            DateTime.now(),
      );
    }).toList(growable: false);
    return _hydrateLegacyRows(items);
  }

  Future<List<WalletTransaction>> _hydrateLegacyRows(
    List<WalletTransaction> items,
  ) async {
    if (items.isEmpty) return items;
    final jobIds = items
        .map((item) => item.jobId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final profileIds = items
        .expand((item) => [item.customerId, item.artisanId])
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final jobs = <String, Map<String, dynamic>>{};
    final profiles = <String, Map<String, dynamic>>{};
    if (jobIds.isNotEmpty) {
      final rows = await _client
          .from('jobs')
          .select('id,title,location')
          .inFilter('id', jobIds);
      for (final row in rows) {
        final value = Map<String, dynamic>.from(row as Map);
        jobs[(value['id'] ?? '').toString()] = value;
      }
    }
    if (profileIds.isNotEmpty) {
      final rows = await _client
          .from('profiles')
          .select('id,username,full_name,email')
          .inFilter('id', profileIds);
      for (final row in rows) {
        final value = Map<String, dynamic>.from(row as Map);
        profiles[(value['id'] ?? '').toString()] = value;
      }
    }

    return items.map((item) {
      final job = jobs[item.jobId];
      final customer = profiles[item.customerId];
      final artisan = profiles[item.artisanId];
      return item.copyWith(
        jobTitle: item.jobTitle.isNotEmpty
            ? item.jobTitle
            : (job?['title'] ?? 'Accepted work').toString(),
        jobLocation: item.jobLocation.isNotEmpty
            ? item.jobLocation
            : (job?['location'] ?? '').toString(),
        customerName: item.customerName.isNotEmpty
            ? item.customerName
            : _profileName(customer, 'Customer'),
        customerEmail: item.customerEmail.isNotEmpty
            ? item.customerEmail
            : (customer?['email'] ?? '').toString(),
        artisanName: item.artisanName.isNotEmpty
            ? item.artisanName
            : _profileName(artisan, 'Artisan'),
        artisanEmail: item.artisanEmail.isNotEmpty
            ? item.artisanEmail
            : (artisan?['email'] ?? '').toString(),
      );
    }).toList(growable: false);
  }
}

String _profileName(Map<String, dynamic>? profile, String fallback) {
  final fullName = (profile?['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final username = (profile?['username'] ?? '').toString().trim();
  if (username.isNotEmpty) return username;
  final email = (profile?['email'] ?? '').toString().trim();
  return email.isEmpty ? fallback : email;
}

String _shortId(String value) {
  final normalized = value.replaceAll('-', '').toUpperCase();
  if (normalized.isEmpty) return 'PENDING';
  final end = normalized.length < 12 ? normalized.length : 12;
  return normalized.substring(0, end);
}
