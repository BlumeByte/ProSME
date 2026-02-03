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
      id: json['id'] as String,
      userId: json['userId'] as String,
      artisanId: json['artisanId'] as String,
      lastMessage: json['lastMessage'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'artisanId': artisanId,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt.toIso8601String(),
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
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: json['senderId'] as String,
      type: MessageType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'type': type.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
