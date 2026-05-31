import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/chat_models.dart';

abstract class ChatService {
  Stream<List<ChatThread>> watchThreads(String userId);
  Stream<List<ChatMessage>> watchMessages(String threadId);
  Future<void> sendMessage(ChatMessage message);
}

class MockChatService implements ChatService {
  final Map<String, StreamController<List<ChatThread>>> _threadControllers = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};
  final Map<String, List<ChatThread>> _threadsByUser = {};
  final Map<String, List<ChatMessage>> _messagesByThread = {};
  final Map<String, Set<String>> _threadWatchers = {};

  @override
  Stream<List<ChatThread>> watchThreads(String userId) {
    final controller = _threadControllers.putIfAbsent(
      userId,
      () => StreamController<List<ChatThread>>.broadcast(),
    );
    controller.add(List<ChatThread>.from(_threadsByUser[userId] ?? const []));
    return controller.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    final controller = _messageControllers.putIfAbsent(
      threadId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    _threadWatchers.putIfAbsent(threadId, () => <String>{});
    controller.add(
      List<ChatMessage>.from(_messagesByThread[threadId] ?? const []),
    );
    return controller.stream;
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final messages = _messagesByThread.putIfAbsent(
      message.threadId,
      () => <ChatMessage>[],
    );
    messages.add(message);
    _messageControllers[message.threadId]?.add(List<ChatMessage>.from(messages));

    final ownerIds = _threadWatchers[message.threadId] ?? <String>{};
    ownerIds.add(message.senderId);
    _threadWatchers[message.threadId] = ownerIds;

    for (final ownerId in ownerIds) {
      final threads = _threadsByUser.putIfAbsent(ownerId, () => <ChatThread>[]);
      final index = threads.indexWhere((thread) => thread.id == message.threadId);
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
  Stream<List<ChatThread>> watchThreads(String userId) {
    return _supabase.from('threads').stream(primaryKey: ['id']).map(
          (rows) => rows
              .where(
                (row) =>
                    (row['user_id'] ?? row['userId'])?.toString() == userId,
              )
              .map((row) => ChatThread.fromJson(row))
              .toList(),
        );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _supabase.from('messages').stream(primaryKey: ['id']).map(
          (rows) => rows
              .where(
                (row) =>
                    (row['thread_id'] ?? row['threadId'])?.toString() ==
                    threadId,
              )
              .map((row) => ChatMessage.fromJson(row))
              .toList(),
        );
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    await _supabase.from('messages').insert(message.toJson());
  }
}

ChatService buildChatService(SupabaseClient supabase) {
  return kDevMode ? MockChatService() : SupabaseChatService(supabase);
}
