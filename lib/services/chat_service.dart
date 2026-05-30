import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../core/utils/mock_data.dart';
import '../models/chat_models.dart';

abstract class ChatService {
  Stream<List<ChatThread>> watchThreads(String userId);
  Stream<List<ChatMessage>> watchMessages(String threadId);
  Future<void> sendMessage(ChatMessage message);
}

class MockChatService implements ChatService {
  final StreamController<List<ChatThread>> _threadController =
      StreamController<List<ChatThread>>.broadcast();
  final StreamController<List<ChatMessage>> _messageController =
      StreamController<List<ChatMessage>>.broadcast();

  MockChatService() {
    _threadController.add(demoChatThreads);
    _messageController.add(demoMessages);
  }

  @override
  Stream<List<ChatThread>> watchThreads(String userId) =>
      _threadController.stream;

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) =>
      _messageController.stream;

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final updated = List<ChatMessage>.from(demoMessages)..add(message);
    _messageController.add(updated);
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
