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

    dynamic query = _client.from('wallet_transactions').select();
    if (role != UserRole.admin && role != UserRole.developer) {
      query = query.or('user_id.eq.$userId,artisan_id.eq.$userId');
    }
    final rows = await query.order('created_at', ascending: false);
    final items = rows
        .map((row) => WalletTransaction.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
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
