import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/chat_models.dart';

abstract class ChatService {
  Stream<List<ChatThread>> watchThreads(String userId);
  Stream<List<ChatMessage>> watchMessages(String threadId);
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  });
  Future<void> sendMessage(ChatMessage message);
  Future<void> updateMessage(ChatMessage message);
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
  });
  Future<void> clearMessages(String threadId);
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
  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
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
          lastMessage: message.content,
          updatedAt: message.createdAt,
        );
        threads.insert(0, updatedThread);
      } else {
        final updatedThread = threads[index].copyWith(
          lastMessage: message.content,
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
  }) async {
    final messages = _messagesByThread[threadId];
    if (messages == null) return;
    messages.removeWhere((message) => message.id == messageId);
    _messageControllers[threadId]?.add(List<ChatMessage>.from(messages));
    _refreshThreadSummaries(threadId);
  }

  @override
  Future<void> clearMessages(String threadId) async {
    _messagesByThread[threadId] = <ChatMessage>[];
    _messageControllers[threadId]?.add(const <ChatMessage>[]);
    _refreshThreadSummaries(threadId);
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
        lastMessage: lastMessage?.content ?? '',
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
  SupabaseChatService(this._supabase);

  final SupabaseClient _supabase;

  @override
  Stream<List<ChatThread>> watchThreads(String userId) async* {
    var lastGood = const <ChatThread>[];
    while (true) {
      try {
        final rows = await _supabase
            .from('threads')
            .select()
            .or('user_id.eq.$userId,artisan_id.eq.$userId')
            .order('updated_at', ascending: false);
        lastGood = await _hydrateThreads(rows
            .map((row) => ChatThread.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false));
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh chat threads: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 6));
    }
  }

  Future<List<ChatThread>> _hydrateThreads(List<ChatThread> threads) async {
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
          .select('id,full_name,email,avatar_url')
          .inFilter('id', profileIds.toList());
      final profiles = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final profile = Map<String, dynamic>.from(row);
        profiles[(profile['id'] ?? '').toString()] = profile;
      }

      String? nameFor(String id) {
        final profile = profiles[id];
        final fullName = (profile?['full_name'] ?? '').toString().trim();
        if (fullName.isNotEmpty) return fullName;
        final email = (profile?['email'] ?? '').toString().trim();
        if (email.isEmpty) return null;
        return email.split('@').first;
      }

      String? photoFor(String id) {
        final value = (profiles[id]?['avatar_url'] ?? '').toString().trim();
        return value.isEmpty ? null : value;
      }

      return threads
          .map(
            (thread) => thread.copyWith(
              userName: nameFor(thread.userId),
              userPhotoUrl: photoFor(thread.userId),
              artisanName: nameFor(thread.artisanId),
              artisanPhotoUrl: photoFor(thread.artisanId),
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
  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
    var lastGood = const <ChatMessage>[];
    while (true) {
      try {
        final rows = await _supabase
            .from('messages')
            .select()
            .eq('thread_id', threadId)
            .order('created_at');
        final seen = <String>{};
        lastGood = rows
            .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
            .where((message) => seen.add(message.id))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh chat messages: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  @override
  Future<ChatThread> createOrOpenThread({
    required String userId,
    required String artisanId,
  }) async {
    final existingRows = await _supabase
        .from('threads')
        .select()
        .eq('user_id', userId)
        .eq('artisan_id', artisanId)
        .limit(1);
    if (existingRows.isNotEmpty) {
      return ChatThread.fromJson(
        Map<String, dynamic>.from(existingRows.first as Map),
      );
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
    return ChatThread.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    await _supabase.from('messages').insert(message.toJson());
    await _supabase.from('threads').update({
      'last_message': message.content,
      'updated_at': message.createdAt.toIso8601String(),
    }).eq('id', message.threadId);
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    await _supabase
        .from('messages')
        .update({'content': message.content}).eq('id', message.id);
    await _refreshThreadSummary(message.threadId);
  }

  @override
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
  }) async {
    await _supabase.from('messages').delete().eq('id', messageId);
    await _refreshThreadSummary(threadId);
  }

  @override
  Future<void> clearMessages(String threadId) async {
    await _supabase.from('messages').delete().eq('thread_id', threadId);
    await _refreshThreadSummary(threadId);
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
      'last_message': lastMessage?.content ?? '',
      'updated_at': (lastMessage?.createdAt ?? DateTime.now()).toIso8601String(),
    }).eq('id', threadId);
  }
}

ChatService buildChatService(SupabaseClient supabase) {
  return kDevMode ? MockChatService() : SupabaseChatService(supabase);
}
