import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_models.dart';
import 'chat_service.dart';
import 'db_service.dart';

/// Adds Supabase Realtime invalidation/update handling to the existing
/// offline-first chat service. Local cache remains the UI source of truth,
/// while inserts/updates made on web or another phone arrive immediately.
class RealtimeChatService implements ChatService {
  RealtimeChatService(this._supabase, this._localDb)
      : _delegate =
            SupabaseChatService(_supabase, _localDb, pollInterval: null);

  final SupabaseClient _supabase;
  final LocalDbService _localDb;
  final SupabaseChatService _delegate;
  final Map<String, RealtimeChannel> _threadChannels = {};
  final Map<String, RealtimeChannel> _messageChannels = {};
  final Map<String, int> _threadWatchCounts = {};
  final Map<String, int> _messageWatchCounts = {};

  @override
  Stream<List<ChatThread>> watchThreads(String userId) {
    _retainThreadChannel(userId);
    final base = _delegate.watchThreads(userId);
    return Stream<List<ChatThread>>.multi((controller) {
      final sub = base.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        await sub.cancel();
        await _releaseThreadChannel(userId);
      };
    });
  }

  void _retainThreadChannel(String userId) {
    _threadWatchCounts.update(userId, (value) => value + 1, ifAbsent: () => 1);
    if (_threadChannels.containsKey(userId)) return;

    final channel = _supabase.channel(
      'prosme:user:$userId',
      opts: const RealtimeChannelConfig(private: true),
    );

    void handleThreadChange(Map<String, dynamic> payload) {
      final row = _broadcastRecord(payload);
      if (row.isEmpty) return;
      final thread = ChatThread.fromJson(row);
      if (thread.userId != userId && thread.artisanId != userId) return;
      unawaited(_localDb.upsertThreadForParticipants(thread));
    }

    channel
        .onBroadcast(event: 'thread_insert', callback: handleThreadChange)
        .onBroadcast(event: 'thread_update', callback: handleThreadChange)
        .subscribe();
    _threadChannels[userId] = channel;
  }

  Future<void> _releaseThreadChannel(String userId) async {
    final next = (_threadWatchCounts[userId] ?? 1) - 1;
    if (next > 0) {
      _threadWatchCounts[userId] = next;
      return;
    }
    _threadWatchCounts.remove(userId);
    final channel = _threadChannels.remove(userId);
    if (channel != null) await _supabase.removeChannel(channel);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId, {String? userId}) {
    _retainMessageChannel(threadId);
    final base = _delegate.watchMessages(threadId, userId: userId);
    return Stream<List<ChatMessage>>.multi((controller) {
      final sub = base.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        await sub.cancel();
        await _releaseMessageChannel(threadId);
      };
    });
  }

  void _retainMessageChannel(String threadId) {
    _messageWatchCounts.update(
      threadId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    if (_messageChannels.containsKey(threadId)) return;

    final channel = _supabase.channel(
      'prosme:thread:$threadId',
      opts: const RealtimeChannelConfig(private: true),
    );

    void upsertMessage(Map<String, dynamic> payload) {
      final row = _broadcastRecord(payload);
      if (row.isEmpty || (row['thread_id'] ?? '').toString() != threadId) {
        return;
      }
      unawaited(_localDb.upsertMessage(ChatMessage.fromJson(row)));
    }

    channel
        .onBroadcast(event: 'message_insert', callback: upsertMessage)
        .onBroadcast(event: 'message_update', callback: upsertMessage)
        .onBroadcast(
          event: 'message_delete',
          callback: (payload) {
            final row = _broadcastRecord(payload);
            if ((row['thread_id'] ?? '').toString() != threadId) return;
            final id = (row['id'] ?? '').toString();
            if (id.isNotEmpty) {
              unawaited(_localDb.deleteMessage(threadId, id));
            }
          },
        )
        .subscribe();
    _messageChannels[threadId] = channel;
  }

  Future<void> _releaseMessageChannel(String threadId) async {
    final next = (_messageWatchCounts[threadId] ?? 1) - 1;
    if (next > 0) {
      _messageWatchCounts[threadId] = next;
      return;
    }
    _messageWatchCounts.remove(threadId);
    final channel = _messageChannels.remove(threadId);
    if (channel != null) await _supabase.removeChannel(channel);
  }

  @override
  Future<void> markThreadRead(String threadId, String userId) =>
      _delegate.markThreadRead(threadId, userId);

  @override
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  }) =>
      _delegate.createOrOpenThread(userId: userId, artisanId: artisanId);

  @override
  Future<void> sendMessage(ChatMessage message) =>
      _delegate.sendMessage(message);

  @override
  Future<void> updateMessage(ChatMessage message) =>
      _delegate.updateMessage(message);

  @override
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
    String? deletedForUserId,
  }) =>
      _delegate.deleteMessage(
        threadId: threadId,
        messageId: messageId,
        deletedForUserId: deletedForUserId,
      );

  @override
  Future<void> deleteMessagesForUser({
    required String threadId,
    required String userId,
    required Iterable<String> messageIds,
  }) =>
      _delegate.deleteMessagesForUser(
        threadId: threadId,
        userId: userId,
        messageIds: messageIds,
      );

  @override
  Future<void> clearMessages(String threadId, {String? clearedForUserId}) =>
      _delegate.clearMessages(threadId, clearedForUserId: clearedForUserId);

  @override
  Future<void> deleteThreadForUser({
    required String threadId,
    required String userId,
  }) =>
      _delegate.deleteThreadForUser(threadId: threadId, userId: userId);

  Future<void> dispose() async {
    final channels = [..._threadChannels.values, ..._messageChannels.values];
    _threadChannels.clear();
    _messageChannels.clear();
    for (final channel in channels) {
      await _supabase.removeChannel(channel);
    }
  }

  static Map<String, dynamic> _broadcastRecord(Map<String, dynamic> payload) {
    final nested = payload['payload'];
    final body = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(payload);
    final record = body['record'] ?? body['new'] ?? body['old_record'];
    return record is Map ? Map<String, dynamic>.from(record) : const {};
  }
}
