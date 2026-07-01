import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

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
        .order('created_at', ascending: false);
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
        if (deleted.isEmpty) {
          throw StateError(settings.t('Notification could not be deleted.'));
        }
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
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
                      child: ListTile(
                        leading: Icon(
                          item.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                        ),
                        title: Text(settings.t(item.title)),
                        subtitle: Text(
                          [
                            if (item.body.isNotEmpty) settings.t(item.body),
                            DateFormat('MMM d, y h:mm a')
                                .format(item.createdAt),
                            settings.t(item.type.replaceAll('_', ' ')),
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (!item.isRead)
                              IconButton(
                                onPressed: () => _markRead(item),
                                icon: const Icon(Icons.done),
                                tooltip: settings.t('Mark read'),
                              ),
                            IconButton(
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

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

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
    );
  }
}
