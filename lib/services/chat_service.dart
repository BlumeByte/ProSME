import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class FirestoreChatService implements ChatService {
  FirestoreChatService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ChatThread>> watchThreads(String userId) {
    return _firestore
        .collection('threads')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatThread.fromJson(doc.data())).toList());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _firestore
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    await _firestore
        .collection('threads')
        .doc(message.threadId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());
  }
}

ChatService buildChatService(FirebaseFirestore firestore) {
  return kDevMode ? MockChatService() : FirestoreChatService(firestore);
}
