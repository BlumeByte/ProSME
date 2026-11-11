import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/app_user.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../home/account_completion.dart';
import '../home/account_status_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  DateTimeRange? _dateRange;
  late Future<List<_NotificationItem>> _future;
  final Set<String> _deletingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadNotifications();
  }

  Future<List<_NotificationItem>> _loadNotifications() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || !shouldUseSupabase()) return const [];
    final rows = await ref
        .read(supabaseClientProvider)
        .from('admin_notifications')
        .select()
        .or('related_user_id.eq.${user.id},actor_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(200);
    return rows
        .map((row) => _NotificationItem.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  List<_NotificationItem> _applyFilters(List<_NotificationItem> items) {
    return items.where((item) {
      final statusMatches = _statusFilter == 'all' ||
          (_statusFilter == 'read' && item.isRead) ||
          (_statusFilter == 'unread' && !item.isRead);
      final typeMatches = _typeFilter == 'all' || item.type == _typeFilter;
      final range = _dateRange;
      final dateMatches = range == null ||
          (!item.createdAt.isBefore(range.start) &&
              item.createdAt.isBefore(
                range.end.add(const Duration(days: 1)),
              ));
      return statusMatches && typeMatches && dateMatches;
    }).toList(growable: false);
  }

  Future<void> _markRead(_NotificationItem item) async {
    if (!shouldUseSupabase()) return;
    await ref.read(supabaseClientProvider).from('admin_notifications').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', item.id);
    setState(() => _future = _loadNotifications());
  }

  Future<void> _openNotificationDetail(
    _NotificationItem item,
    AppSettings settings,
  ) async {
    if (!item.isRead) {
      try {
        await _markRead(item);
      } catch (_) {
        // Detail viewing should still work even if marking read fails.
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.62,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          settings.t(item.title),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (item.body.trim().isNotEmpty)
                    SelectableText(
                      settings.t(item.body),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                          ),
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  _NotificationMetaRow(
                    icon: Icons.schedule_outlined,
                    label: settings.t('Date'),
                    value: DateFormat('MMM d, y h:mm a')
                        .format(item.createdAt.toLocal()),
                  ),
                  _NotificationMetaRow(
                    icon: Icons.category_outlined,
                    label: settings.t('Type'),
                    value: settings.t(item.type.replaceAll('_', ' ')),
                  ),
                  if (item.relatedTable.isNotEmpty)
                    _NotificationMetaRow(
                      icon: Icons.link_outlined,
                      label: settings.t('Related to'),
                      value: item.relatedTable.replaceAll('_', ' '),
                    ),
                  if (item.relatedId.isNotEmpty)
                    _NotificationMetaRow(
                      icon: Icons.tag_outlined,
                      label: settings.t('Reference'),
                      value: item.relatedId,
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _deletingIds.contains(item.id)
                          ? null
                          : () async {
                              final deleted = await _deleteNotification(item);
                              if (deleted && sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(settings.t('Delete')),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _deleteNotification(_NotificationItem item) async {
    if (_deletingIds.contains(item.id)) return false;
    final settings = ref.read(appSettingsControllerProvider);
    setState(() => _deletingIds.add(item.id));
    try {
      if (shouldUseSupabase()) {
        final deleted = await ref
            .read(supabaseClientProvider)
            .from('admin_notifications')
            .delete()
            .eq('id', item.id)
            .select('id');
        // A zero-row delete is already the desired visible state. This can
        // happen if realtime/refetch removed the row before the delete returns.
        debugPrint('Deleted notification rows: ${deleted.length}');
      }
      if (!mounted) return true;
      setState(() => _future = _loadNotifications());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Notification deleted.'))),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.t('Could not delete notification. Please try again.'),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _deletingIds.remove(item.id));
    }
  }

  void _openCompletionItem(AppUser user, AccountCompletionItem item) {
    // Profile tab index differs per role's home shell (see user_home_screen
    // / artisan_home_screen); admins never see these items at all.
    final tabIndex = user.role == UserRole.artisan ? 4 : 3;
    final home =
        user.role == UserRole.artisan ? RouteNames.artisanHome : RouteNames.home;
    ref.read(requestedProfileActionProvider.notifier).state = item.action;
    ref.read(requestedHomeTabProvider.notifier).state = tabIndex;
    context.go(home);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (selected != null) {
      setState(() => _dateRange = selected);
    }
  }

  String _actionSubtitle(AppSettings settings, AccountCompletionAction action) {
    switch (action) {
      case AccountCompletionAction.accountSettings:
        return settings.t('Tap to add it in Account settings.');
      case AccountCompletionAction.photo:
        return settings.t('Tap to add a profile photo.');
      case AccountCompletionAction.verifyEmail:
        return settings.t('Tap to send yourself a 6-digit code.');
      case AccountCompletionAction.verifyPhone:
        return settings.t('Tap to send yourself an SMS code.');
      case AccountCompletionAction.artisanVerification:
        return settings.t('Tap to submit your documents for review.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final completionItems = ref.watch(accountCompletionItemsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Notifications')),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _loadNotifications()),
            icon: const Icon(Icons.refresh),
            tooltip: settings.t('Refresh'),
          ),
        ],
      ),
      body: FutureBuilder<List<_NotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(settings.t('Could not load notifications.')),
            );
          }
          if (!snapshot.hasData) {
            return LoadingState(label: settings.t('Loading notifications...'));
          }
          final items = snapshot.data!;
          final types = items.map((item) => item.type).toSet().toList()..sort();
          final filtered = _applyFilters(items);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user != null && completionItems.isNotEmpty) ...[
                Text(
                  settings.t('Finish setting up your account'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final item in completionItems)
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.priority_high,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                      title: Text(
                        '${settings.t('Complete')}: ${settings.t(item.label)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _actionSubtitle(settings, item.action),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                      onTap: () => _openCompletionItem(user, item),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        label: Text(settings.t('All')),
                      ),
                      ButtonSegment(
                        value: 'unread',
                        label: Text(settings.t('Unread')),
                      ),
                      ButtonSegment(
                        value: 'read',
                        label: Text(settings.t('Read')),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _statusFilter = selection.first),
                  ),
                  DropdownMenu<String>(
                    initialSelection: _typeFilter,
                    label: Text(settings.t('Type')),
                    dropdownMenuEntries: [
                      DropdownMenuEntry(
                        value: 'all',
                        label: settings.t('All'),
                      ),
                      ...types.map(
                        (type) => DropdownMenuEntry(
                          value: type,
                          label: type.replaceAll('_', ' '),
                        ),
                      ),
                    ],
                    onSelected: (value) =>
                        setState(() => _typeFilter = value ?? 'all'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dateRange == null
                          ? settings.t('Date')
                          : '${DateFormat.MMMd().format(_dateRange!.start)} - ${DateFormat.MMMd().format(_dateRange!.end)}',
                    ),
                  ),
                  if (_dateRange != null)
                    IconButton(
                      onPressed: () => setState(() => _dateRange = null),
                      icon: const Icon(Icons.clear),
                      tooltip: settings.t('Clear date filter'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text(settings.t('No notifications')),
                  ),
                )
              else
                ...filtered.map(
                  (item) => Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.horizontal,
                    background: const _DeleteBackground(
                        alignment: Alignment.centerLeft),
                    secondaryBackground: const _DeleteBackground(
                        alignment: Alignment.centerRight),
                    confirmDismiss: (_) async {
                      await _deleteNotification(item);
                      // The refreshed Future owns list removal. Returning true
                      // would make Dismissible remove the same row a second time.
                      return false;
                    },
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openNotificationDetail(item, settings),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      item.isRead
                                          ? Icons.notifications_none
                                          : Icons.notifications_active,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      settings.t(item.title),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (!item.isRead)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _markRead(item),
                                      icon: const Icon(Icons.done),
                                      tooltip: settings.t('Mark read'),
                                    ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _deletingIds.contains(item.id)
                                        ? null
                                        : () => _deleteNotification(item),
                                    icon: _deletingIds.contains(item.id)
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_outline),
                                    tooltip: settings.t('Delete'),
                                  ),
                                ],
                              ),
                              if (item.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: Text(
                                    settings.t(item.body),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.35),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(left: 36),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      DateFormat('MMM d, y h:mm a')
                                          .format(item.createdAt.toLocal()),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      settings
                                          .t(item.type.replaceAll('_', ' ')),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      settings.t('Tap to view'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

class _NotificationMetaRow extends StatelessWidget {
  const _NotificationMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.relatedTable,
    required this.relatedId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String relatedTable;
  final String relatedId;

  bool get isRead => readAt != null;

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    return _NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'general').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      readAt: DateTime.tryParse((json['read_at'] ?? '').toString()),
      relatedTable: (json['related_table'] ?? '').toString(),
      relatedId: (json['related_id'] ?? '').toString(),
    );
  }
}
