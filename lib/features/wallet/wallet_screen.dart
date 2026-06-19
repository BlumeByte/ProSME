import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: Text(settings.t('Wallet')),
        ),
        body: Center(child: Text(settings.t('Sign in to continue'))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Wallet')),
      ),
      body: FutureBuilder<List<_WalletTransaction>>(
        future: _loadTransactions(ref, user.id, user.role),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(settings.t('Could not load wallet.')));
          }
          if (!snapshot.hasData) {
            return LoadingState(label: settings.t('Loading wallet...'));
          }
          final items = snapshot.data!;
          final currencyCode = settings.currencyCode;
          final total = items.fold<double>(
            0,
            (sum, item) => sum + item.amount,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(settings.t('Tracked accepted bids')),
                  subtitle: Text(settings.t('Money flow from accepted work.')),
                  trailing: Text(
                    formatMoney(total, currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(settings.t('No wallet activity yet')),
                  ),
                )
              else
                ...items.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(formatMoney(item.amount, currencyCode)),
                      subtitle: Text(
                        [
                          settings.t(item.eventType.replaceAll('_', ' ')),
                          DateFormat('MMM d, y h:mm a').format(item.createdAt),
                          if (item.jobId.isNotEmpty) 'Job: ${item.jobId}',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<List<_WalletTransaction>> _loadTransactions(
    WidgetRef ref,
    String userId,
    UserRole role,
  ) async {
    if (!shouldUseSupabase()) return const [];
    final table = ref.read(supabaseClientProvider).from('wallet_transactions');
    dynamic query = table.select();
    if (role != UserRole.admin && role != UserRole.developer) {
      query = query.or('user_id.eq.$userId,artisan_id.eq.$userId');
    }
    final rows = await query.order('created_at', ascending: false);
    return rows
        .map((row) => _WalletTransaction.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }
}

class _WalletTransaction {
  const _WalletTransaction({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.eventType,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final double amount;
  final String eventType;
  final DateTime createdAt;

  factory _WalletTransaction.fromJson(Map<String, dynamic> json) {
    return _WalletTransaction(
      id: (json['id'] ?? '').toString(),
      jobId: (json['job_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      eventType: (json['event_type'] ?? 'bid_accepted').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
