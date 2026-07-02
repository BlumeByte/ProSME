import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/chat_models.dart';
import 'chat_sync_service.dart';
import 'db_service.dart';

abstract class ChatService {
  Stream<List<ChatThread>> watchThreads(String userId);
  Stream<List<ChatMessage>> watchMessages(String threadId, {String? userId});
  Future<void> markThreadRead(String threadId, String userId);
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  });
  Future<void> sendMessage(ChatMessage message);
  Future<void> updateMessage(ChatMessage message);
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
    String? deletedForUserId,
  });
  Future<void> deleteMessagesForUser({
    required String threadId,
    required String userId,
    required Iterable<String> messageIds,
  });
  Future<void> clearMessages(String threadId, {String? clearedForUserId});
  Future<void> deleteThreadForUser({
    required String threadId,
    required String userId,
  });
}

class MockChatService implements ChatService {
  final Map<String, StreamController<List<ChatThread>>> _threadControllers = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};
  final Map<String, List<ChatThread>> _threadsByUser = {};
  final Map<String, List<ChatMessage>> _messagesByThread = {};
  final Map<String, Set<String>> _threadWatchers = {};

  @override
  Stream<List<ChatThread>> watchThreads(String userId) async* {
    final controller = _threadControllers.putIfAbsent(
      userId,
      () => StreamController<List<ChatThread>>.broadcast(),
    );
    yield List<ChatThread>.from(_threadsByUser[userId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<void> markThreadRead(String threadId, String userId) async {
    final messages = _messagesByThread[threadId];
    if (messages == null) return;
    final now = DateTime.now();
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      if (message.senderId != userId && message.readAt == null) {
        messages[index] = message.copyWith(readAt: now);
      }
    }
    _messageControllers[threadId]?.add(List<ChatMessage>.from(messages));
  }

  @override
  Stream<List<ChatMessage>> watchMessages(
    String threadId, {
    String? userId,
  }) async* {
    final controller = _messageControllers.putIfAbsent(
      threadId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    _threadWatchers.putIfAbsent(threadId, () => <String>{});
    yield List<ChatMessage>.from(_messagesByThread[threadId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  }) async {
    final pair = [userId, artisanId]..sort();
    final threadId = 'mock_${pair.join('_')}';
    final userThreads = _threadsByUser[userId] ?? const <ChatThread>[];
    for (final thread in userThreads) {
      if (thread.id == threadId) return thread;
    }

    final thread = ChatThread(
      id: threadId,
      userId: userId,
      artisanId: artisanId,
      lastMessage: '',
      updatedAt: DateTime.now(),
    );
    for (final ownerId in {userId, artisanId}) {
      final threads = _threadsByUser.putIfAbsent(ownerId, () => <ChatThread>[]);
      threads.insert(0, thread);
      _threadControllers[ownerId]?.add(List<ChatThread>.from(threads));
    }
    _threadWatchers[threadId] = {userId, artisanId};
    return thread;
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final messages = _messagesByThread.putIfAbsent(
      message.threadId,
      () => <ChatMessage>[],
    );
    messages.add(message);
    _messageControllers[message.threadId]
        ?.add(List<ChatMessage>.from(messages));

    final ownerIds = _threadWatchers[message.threadId] ?? <String>{};
    ownerIds.add(message.senderId);
    _threadWatchers[message.threadId] = ownerIds;

    for (final ownerId in ownerIds) {
      final threads = _threadsByUser.putIfAbsent(ownerId, () => <ChatThread>[]);
      final index =
          threads.indexWhere((thread) => thread.id == message.threadId);
      if (index == -1) {
        final updatedThread = ChatThread(
          id: message.threadId,
          userId: ownerId,
          artisanId: '',
          lastMessage: message.threadPreview,
          updatedAt: message.createdAt,
        );
        threads.insert(0, updatedThread);
      } else {
        final updatedThread = threads[index].copyWith(
          lastMessage: message.threadPreview,
          updatedAt: message.createdAt,
        );
        threads
          ..removeAt(index)
          ..insert(0, updatedThread);
      }
      _threadControllers[ownerId]?.add(List<ChatThread>.from(threads));
    }
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    final messages = _messagesByThread[message.threadId];
    if (messages == null) return;
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index == -1) return;
    messages[index] = message;
    _messageControllers[message.threadId]
        ?.add(List<ChatMessage>.from(messages));
    _refreshThreadSummaries(message.threadId);
  }

  @override
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
    String? deletedForUserId,
  }) async {
    final messages = _messagesByThread[threadId];
    if (messages == null) return;
    messages.removeWhere((message) => message.id == messageId);
    _messageControllers[threadId]?.add(List<ChatMessage>.from(messages));
    _refreshThreadSummaries(threadId);
  }

  @override
  Future<void> deleteMessagesForUser({
    required String threadId,
    required String userId,
    required Iterable<String> messageIds,
  }) async {
    for (final messageId in messageIds) {
      await deleteMessage(threadId: threadId, messageId: messageId);
    }
  }

  @override
  Future<void> clearMessages(String threadId,
      {String? clearedForUserId}) async {
    _messagesByThread[threadId] = <ChatMessage>[];
    _messageControllers[threadId]?.add(const <ChatMessage>[]);
    _refreshThreadSummaries(threadId);
  }

  @override
  Future<void> deleteThreadForUser({
    required String threadId,
    required String userId,
  }) async {
    final threads = _threadsByUser[userId];
    threads?.removeWhere((thread) => thread.id == threadId);
    _threadControllers[userId]?.add(List<ChatThread>.from(threads ?? const []));
  }

  void _refreshThreadSummaries(String threadId) {
    final messages = _messagesByThread[threadId] ?? const <ChatMessage>[];
    final lastMessage = messages.isEmpty ? null : messages.last;
    final ownerIds = _threadWatchers[threadId] ?? <String>{};

    for (final ownerId in ownerIds) {
      final threads = _threadsByUser[ownerId];
      if (threads == null) continue;
      final index = threads.indexWhere((thread) => thread.id == threadId);
      if (index == -1) continue;
      final current = threads[index];
      final updatedThread = current.copyWith(
        lastMessage: lastMessage?.threadPreview ?? '',
        updatedAt: lastMessage?.createdAt ?? DateTime.now(),
      );
      threads
        ..removeAt(index)
        ..insert(0, updatedThread);
      _threadControllers[ownerId]?.add(List<ChatThread>.from(threads));
    }
  }
}

class SupabaseChatService implements ChatService {
  SupabaseChatService(this._supabase, this._localDb);

  final SupabaseClient _supabase;
  final LocalDbService _localDb;

  @override
  Stream<List<ChatThread>> watchThreads(String userId) {
    late final StreamController<List<ChatThread>> controller;
    StreamSubscription<List<ChatThread>>? localSub;
    Timer? refreshTimer;

    Future<void> refresh() async {
      try {
        await ChatSyncService.syncPending(
          supabase: _supabase,
          localDb: _localDb,
        );
        final rows = await _supabase
            .from('threads')
            .select()
            .or('user_id.eq.$userId,artisan_id.eq.$userId')
            .order('updated_at', ascending: false);
        final remoteThreads = await _hydrateThreads(
            userId,
            _dedupeThreads(rows
                .map((row) =>
                    ChatThread.fromJson(Map<String, dynamic>.from(row)))
                .toList(growable: false)));
        await _localDb.cacheThreadsForUser(userId, remoteThreads);
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh chat threads: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    controller = StreamController<List<ChatThread>>.broadcast(
      onListen: () {
        localSub = _localDb
            .watchThreads(userId)
            .distinct(_threadListsEqual)
            .listen(controller.add, onError: controller.addError);
        unawaited(refresh());
        refreshTimer = Timer.periodic(
          const Duration(seconds: 20),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        refreshTimer?.cancel();
        await localSub?.cancel();
      },
    );

    return controller.stream.distinct(_threadListsEqual);
  }

  List<ChatThread> _dedupeThreads(List<ChatThread> threads) {
    final byPair = <String, ChatThread>{};
    for (final thread in threads) {
      final pair = [thread.userId, thread.artisanId]..sort();
      final key = pair.join(':');
      final existing = byPair[key];
      if (existing == null || thread.updatedAt.isAfter(existing.updatedAt)) {
        byPair[key] = thread;
      }
    }
    final values = byPair.values.toList(growable: false);
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  Future<List<ChatThread>> _hydrateThreads(
      String userId, List<ChatThread> threads) async {
    if (threads.isEmpty) return threads;
    final profileIds = <String>{};
    for (final thread in threads) {
      if (thread.userId.isNotEmpty) profileIds.add(thread.userId);
      if (thread.artisanId.isNotEmpty) profileIds.add(thread.artisanId);
    }
    if (profileIds.isEmpty) return threads;

    try {
      final rows = await _supabase
          .from('profiles')
          .select('id,username,full_name,email,avatar_url')
          .inFilter('id', profileIds.toList());
      final profiles = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final profile = Map<String, dynamic>.from(row);
        profiles[(profile['id'] ?? '').toString()] = profile;
      }

      String? nameFor(String id) {
        final profile = profiles[id];
        final fullName = (profile?['username'] ?? profile?['full_name'] ?? '')
            .toString()
            .trim();
        if (fullName.isNotEmpty) return fullName;
        final email = (profile?['email'] ?? '').toString().trim();
        if (email.isEmpty) return null;
        return email.split('@').first;
      }

      String? photoFor(String id) {
        final value = (profiles[id]?['avatar_url'] ?? '').toString().trim();
        return value.isEmpty ? null : value;
      }

      final unreadRows = await _supabase
          .from('messages')
          .select('thread_id')
          .neq('sender_id', userId)
          .isFilter('read_at', null)
          .inFilter('thread_id', threads.map((thread) => thread.id).toList());
      final unreadCounts = <String, int>{};
      for (final row in unreadRows) {
        final threadId = (row['thread_id'] ?? '').toString();
        unreadCounts.update(threadId, (value) => value + 1, ifAbsent: () => 1);
      }

      return threads
          .map(
            (thread) => thread.copyWith(
              userName: nameFor(thread.userId),
              userPhotoUrl: photoFor(thread.userId),
              artisanName: nameFor(thread.artisanId),
              artisanPhotoUrl: photoFor(thread.artisanId),
              unreadCount: unreadCounts[thread.id] ?? 0,
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate chat profiles: $error');
      debugPrintStack(stackTrace: stackTrace);
      return threads;
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(
    String threadId, {
    String? userId,
  }) {
    late final StreamController<List<ChatMessage>> controller;
    StreamSubscription<List<ChatMessage>>? localSub;
    Timer? refreshTimer;

    Future<List<ChatMessage>> visibleLocal() {
      return userId == null
          ? _localDb.loadMessages(threadId)
          : _localDb.loadVisibleMessages(threadId, userId);
    }

    Future<void> emitVisibleLocal() async {
      if (controller.isClosed) return;
      controller.add(await visibleLocal());
    }

    Future<void> refresh() async {
      try {
        await ChatSyncService.syncPending(
          supabase: _supabase,
          localDb: _localDb,
        );
        final rows = await _supabase
            .from('messages')
            .select()
            .eq('thread_id', threadId)
            .order('created_at');
        final seen = <String>{};
        final remoteMessages = rows
            .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
            .where((message) => seen.add(message.id))
            .toList(growable: false)
          ..sort(_compareMessages);
        await _localDb.cacheMessages(
          threadId,
          remoteMessages,
          emit: false,
        );
        await emitVisibleLocal();
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh chat messages: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      onListen: () {
        localSub = _localDb.watchMessages(threadId).listen((_) {
          unawaited(emitVisibleLocal());
        }, onError: controller.addError);
        unawaited(emitVisibleLocal());
        unawaited(refresh());
        refreshTimer = Timer.periodic(
          const Duration(seconds: 12),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        refreshTimer?.cancel();
        await localSub?.cancel();
      },
    );

    return controller.stream.distinct(_messageListsEqual);
  }

  @override
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  }) async {
    try {
      final existingRows = await _supabase
          .from('threads')
          .select()
          .eq('user_id', userId)
          .eq('artisan_id', artisanId)
          .limit(1);
      if (existingRows.isNotEmpty) {
        final thread = ChatThread.fromJson(
          Map<String, dynamic>.from(existingRows.first as Map),
        );
        await _localDb.upsertThreadForParticipants(thread);
        return thread;
      }

      final row = await _supabase
          .from('threads')
          .insert({
            'user_id': userId,
            'artisan_id': artisanId,
            'last_message': '',
          })
          .select()
          .single();
      final thread = ChatThread.fromJson(Map<String, dynamic>.from(row));
      await _localDb.upsertThreadForParticipants(thread);
      return thread;
    } catch (error) {
      final pair = [userId, artisanId]..sort();
      final thread = ChatThread(
        id: 'offline_${pair.join('_')}',
        userId: userId,
        artisanId: artisanId,
        lastMessage: '',
        updatedAt: DateTime.now(),
      );
      await _localDb.upsertThreadForParticipants(thread);
      return thread;
    }
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    await _localDb.upsertMessage(message);
    try {
      await ChatSyncService.syncPending(
        supabase: _supabase,
        localDb: _localDb,
      );
      final payload = message.toJson()..remove('updated_at');
      await _supabase.from('messages').upsert(payload, onConflict: 'id');
      await _supabase.from('threads').update({
        'last_message': message.threadPreview,
        'updated_at': message.createdAt.toIso8601String(),
      }).eq('id', message.threadId);
    } catch (_) {
      await _localDb.addPendingChatAction(
        LocalPendingChatAction(
          id: 'create_${message.id}',
          action: LocalPendingAction.create,
          createdAt: DateTime.now(),
          message: message,
        ),
      );
    }
  }

  @override
  Future<void> markThreadRead(String threadId, String userId) async {
    await _supabase
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('thread_id', threadId)
        .neq('sender_id', userId)
        .isFilter('read_at', null);
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    final updated = message.copyWith(updatedAt: DateTime.now());
    await _localDb.upsertMessage(updated);
    try {
      await _supabase
          .from('messages')
          .update({'content': updated.content}).eq('id', updated.id);
      await _refreshThreadSummary(updated.threadId);
      await ChatSyncService.syncPending(
        supabase: _supabase,
        localDb: _localDb,
      );
    } catch (_) {
      await _localDb.addPendingChatAction(
        LocalPendingChatAction(
          id: 'update_${updated.id}',
          action: LocalPendingAction.update,
          createdAt: DateTime.now(),
          message: updated,
        ),
      );
    }
  }

  @override
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
    String? deletedForUserId,
  }) async {
    if (deletedForUserId != null) {
      await _localDb.hideMessagesForUser(threadId, deletedForUserId, [
        messageId,
      ]);
      return;
    }
    await _localDb.deleteMessage(threadId, messageId);
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
      await _refreshThreadSummary(threadId);
      await ChatSyncService.syncPending(
        supabase: _supabase,
        localDb: _localDb,
      );
    } catch (_) {
      await _localDb.addPendingChatAction(
        LocalPendingChatAction(
          id: 'delete_$messageId',
          action: LocalPendingAction.delete,
          createdAt: DateTime.now(),
          threadId: threadId,
          messageId: messageId,
        ),
      );
    }
  }

  @override
  Future<void> deleteMessagesForUser({
    required String threadId,
    required String userId,
    required Iterable<String> messageIds,
  }) async {
    await _localDb.hideMessagesForUser(threadId, userId, messageIds);
  }

  @override
  Future<void> clearMessages(String threadId,
      {String? clearedForUserId}) async {
    final messages = await _localDb.loadMessages(threadId);
    if (clearedForUserId != null) {
      await _localDb.hideMessagesForUser(
        threadId,
        clearedForUserId,
        messages.map((message) => message.id),
      );
      return;
    }
    await _localDb.clearMessages(threadId);
    try {
      await _supabase.from('messages').delete().eq('thread_id', threadId);
      await _refreshThreadSummary(threadId);
      await ChatSyncService.syncPending(
        supabase: _supabase,
        localDb: _localDb,
      );
    } catch (_) {
      for (final message in messages) {
        await _localDb.addPendingChatAction(
          LocalPendingChatAction(
            id: 'delete_${message.id}',
            action: LocalPendingAction.delete,
            createdAt: DateTime.now(),
            threadId: threadId,
            messageId: message.id,
          ),
        );
      }
    }
  }

  @override
  Future<void> deleteThreadForUser({
    required String threadId,
    required String userId,
  }) async {
    await _localDb.hideThreadForUser(threadId, userId);
    try {
      final current = await _supabase
          .from('threads')
          .select('user_id,artisan_id')
          .eq('id', threadId)
          .maybeSingle();
      final customerId = (current?['user_id'] ?? '').toString();
      final artisanId = (current?['artisan_id'] ?? '').toString();
      if (customerId.isNotEmpty && artisanId.isNotEmpty) {
        final duplicates = await _supabase
            .from('threads')
            .select('id')
            .eq('user_id', customerId)
            .eq('artisan_id', artisanId);
        for (final row in duplicates) {
          final duplicateId = (row['id'] ?? '').toString();
          if (duplicateId.isNotEmpty) {
            await _localDb.hideThreadForUser(duplicateId, userId);
            await _hideRemoteThreadForUser(duplicateId);
          }
        }
        return;
      }
    } catch (_) {
      // Fall back to hiding the selected row locally.
    }
    await _hideRemoteThreadForUser(threadId);
  }

  Future<void> _hideRemoteThreadForUser(String threadId) async {
    try {
      await _supabase.rpc(
        'delete_thread_for_current_user',
        params: {'p_thread_id': threadId},
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to persist chat deletion: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshThreadSummary(String threadId) async {
    final rows = await _supabase
        .from('messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(1);
    final lastMessage = rows.isEmpty
        ? null
        : ChatMessage.fromJson(Map<String, dynamic>.from(rows.first as Map));
    await _supabase.from('threads').update({
      'last_message': lastMessage?.threadPreview ?? '',
      'updated_at':
          (lastMessage?.createdAt ?? DateTime.now()).toIso8601String(),
    }).eq('id', threadId);
  }

  static bool _threadListsEqual(
    List<ChatThread> previous,
    List<ChatThread> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index += 1) {
      final a = previous[index];
      final b = next[index];
      if (a.id != b.id ||
          a.lastMessage != b.lastMessage ||
          a.updatedAt != b.updatedAt ||
          a.unreadCount != b.unreadCount ||
          a.userName != b.userName ||
          a.userPhotoUrl != b.userPhotoUrl ||
          a.artisanName != b.artisanName ||
          a.artisanPhotoUrl != b.artisanPhotoUrl) {
        return false;
      }
    }
    return true;
  }

  static bool _messageListsEqual(
    List<ChatMessage> previous,
    List<ChatMessage> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index += 1) {
      final a = previous[index];
      final b = next[index];
      if (a.id != b.id ||
          a.threadId != b.threadId ||
          a.senderId != b.senderId ||
          a.type != b.type ||
          a.content != b.content ||
          a.createdAt != b.createdAt ||
          a.updatedAt != b.updatedAt ||
          a.readAt != b.readAt) {
        return false;
      }
    }
    return true;
  }

  static int _compareMessages(ChatMessage a, ChatMessage b) {
    final byCreatedAt = a.createdAt.compareTo(b.createdAt);
    if (byCreatedAt != 0) return byCreatedAt;
    return a.id.compareTo(b.id);
  }
}

ChatService buildChatService(SupabaseClient supabase, LocalDbService localDb) {
  return kMockMode ? MockChatService() : SupabaseChatService(supabase, localDb);
}
