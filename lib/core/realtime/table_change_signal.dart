import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Wakes a polling loop as soon as one of [tables] changes, instead of
/// re-reading on a short timer. A single realtime channel is shared by every
/// loop that uses the same instance, so opening more screens does not open
/// more connections or more full-table reads.
///
/// [wait] returns when a change arrives or when [fallback] elapses, whichever
/// comes first. The fallback keeps data fresh if a realtime event is missed.
class TableChangeSignal {
  TableChangeSignal(this._client, this._tables);

  final SupabaseClient _client;
  final List<String> _tables;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;

  void _ensureSubscribed() {
    if (_channel != null) return;
    final channel = _client.channel('table-changes-${_tables.join('-')}');
    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          if (!_changes.isClosed && _changes.hasListener) {
            _changes.add(null);
          }
        },
      );
    }
    _channel = channel.subscribe();
  }

  Future<void> wait(Duration fallback) async {
    _ensureSubscribed();
    try {
      await _changes.stream.first.timeout(fallback);
    } on TimeoutException {
      // Fallback interval reached with no change: refresh anyway.
    }
  }
}
