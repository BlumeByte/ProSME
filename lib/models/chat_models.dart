enum MessageType { text, location, invoice, offer }

class ChatThread {
  const ChatThread({
    required this.id,
    required this.userId,
    required this.artisanId,
    required this.lastMessage,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String artisanId;
  final String lastMessage;
  final DateTime updatedAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      artisanId: (json['artisanId'] ?? json['artisan_id'] ?? '').toString(),
      lastMessage:
          (json['lastMessage'] ?? json['last_message'] ?? '').toString(),
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artisan_id': artisanId,
      'last_message': lastMessage,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final MessageType type;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      threadId: (json['threadId'] ?? json['thread_id'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender_id'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (type) => type.name == (json['type'] ?? '').toString(),
        orElse: () => MessageType.text,
      ),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thread_id': threadId,
      'sender_id': senderId,
      'type': type.name,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
