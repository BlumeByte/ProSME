import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/service_providers.dart';

/// Number of unread notifications for the signed-in user (capped at 100 rows
/// fetched). Refreshes when that user's notifications change, rather than
/// polling, so each signed-in device costs one small query per change.
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !shouldUseSupabase()) return Stream.value(0);

  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();

  Future<void> refresh() async {
    try {
      final rows = await client
          .from('admin_notifications')
          .select('id')
          .eq('related_user_id', user.id)
          .isFilter('read_at', null)
          .limit(100);
      if (!controller.isClosed) controller.add(rows.length);
    } catch (_) {
      // Keep the last known count; the badge is not critical.
    }
  }

  refresh();
  final channel = client
      .channel('unread-notifications-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'admin_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'related_user_id',
          value: user.id,
        ),
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});
