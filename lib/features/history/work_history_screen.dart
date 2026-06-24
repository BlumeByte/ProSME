import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/app_user.dart';
import '../../models/work_history.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../../services/work_history_service.dart';

class WorkHistoryScreen extends ConsumerStatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  ConsumerState<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends ConsumerState<WorkHistoryScreen> {
  WorkHistory _history = const WorkHistory(bids: [], requests: []);
  String? _attemptedLoadKey;
  Object? _error;
  bool _loading = false;
  String _bidSort = 'newest';

  Future<void> _load(AppUser user) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _attemptedLoadKey = '${user.id}:${user.role.name}';
    });
    try {
      final history = await WorkHistoryService(
        ref.read(supabaseClientProvider),
      ).load(userId: user.id, role: user.role);
      if (mounted) setState(() => _history = history);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: Text(settings.t('Work history')),
        ),
        body: Center(child: Text(settings.t('Sign in to continue'))),
      );
    }
    final loadKey = '${user.id}:${user.role.name}';
    if (_attemptedLoadKey != loadKey && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(user));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: Text(settings.t('Work history')),
          actions: [
            IconButton(
              onPressed: _loading ? null : () => _load(user),
              icon: const Icon(Icons.refresh),
              tooltip: settings.t('Refresh'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: settings.t('Bid history')),
              Tab(text: settings.t('Request history')),
            ],
          ),
        ),
        body: _loading && _history.bids.isEmpty && _history.requests.isEmpty
            ? LoadingState(label: settings.t('Loading history...'))
            : _error != null
                ? _HistoryError(onRetry: () => _load(user))
                : TabBarView(
                    children: [
                      _BidHistoryList(
                        items: _history.bids,
                        sort: _bidSort,
                        onSortChanged: (value) {
                          if (value != null) {
                            setState(() => _bidSort = value);
                          }
                        },
                      ),
                      _RequestHistoryList(items: _history.requests),
                    ],
                  ),
      ),
    );
  }
}

class _BidHistoryList extends ConsumerWidget {
  const _BidHistoryList({
    required this.items,
    required this.sort,
    required this.onSortChanged,
  });

  final List<BidHistoryItem> items;
  final String sort;
  final ValueChanged<String?> onSortChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    if (items.isEmpty) {
      return Center(child: Text(settings.t('No bid history yet.')));
    }
    final visibleItems = [...items]..sort((a, b) {
        switch (sort) {
          case 'oldest':
            return a.createdAt.compareTo(b.createdAt);
          case 'amount':
            return b.amount.compareTo(a.amount);
          case 'status':
            return a.status.compareTo(b.status);
          case 'newest':
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visibleItems.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return DropdownButtonFormField<String>(
            initialValue: sort,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: settings.t('Sort bid history'),
              prefixIcon: const Icon(Icons.sort),
            ),
            items: [
              DropdownMenuItem(
                  value: 'newest', child: Text(settings.t('Newest first'))),
              DropdownMenuItem(
                  value: 'oldest', child: Text(settings.t('Oldest first'))),
              DropdownMenuItem(
                  value: 'amount', child: Text(settings.t('Highest amount'))),
              DropdownMenuItem(
                  value: 'status', child: Text(settings.t('Status'))),
            ],
            onChanged: onSortChanged,
          );
        }
        final item = visibleItems[index - 1];
        final accepted = item.status == 'accepted';
        return Card(
          child: ListTile(
            leading: Icon(
              accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: accepted ? Colors.green : Colors.red,
            ),
            title: Text(item.jobTitle),
            subtitle: Text(
              '${item.artisanName}\n${DateFormat('MMM d, y h:mm a').format(item.createdAt)}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(item.amount, settings.currencyCode),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(settings.t(item.status)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestHistoryList extends ConsumerWidget {
  const _RequestHistoryList({required this.items});

  final List<RequestHistoryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    if (items.isEmpty) {
      return Center(child: Text(settings.t('No request history yet.')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final amount = item.acceptedAmount ?? item.budget;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.work_history_outlined),
            title: Text(item.title),
            subtitle: Text(
              '${item.location}\n${DateFormat('MMM d, y h:mm a').format(item.createdAt)}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(amount, settings.currencyCode),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(settings.t(item.status)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryError extends ConsumerWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(settings.t('Could not load work history.')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
