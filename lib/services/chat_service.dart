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
      final updatedThread = ChatThread(
        id: message.threadId,
        userId: ownerId,
        artisanId: '',
        lastMessage: message.content,
        updatedAt: message.createdAt,
      );
      if (index == -1) {
        threads.insert(0, updatedThread);
      } else {
        threads
          ..removeAt(index)
          ..insert(0, updatedThread);
      }
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
        lastGood = rows
            .map((row) => ChatThread.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        yield lastGood;
      } catch (error, stackTrace) {
        debugPrint('Failed to refresh chat threads: $error');
        debugPrintStack(stackTrace: stackTrace);
        yield lastGood;
      }
      await Future<void>.delayed(const Duration(seconds: 6));
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
}

ChatService buildChatService(SupabaseClient supabase) {
  return kDevMode ? MockChatService() : SupabaseChatService(supabase);
}
