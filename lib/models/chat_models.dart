enum MessageType { text, location, invoice, offer }

class ChatThread {
  const ChatThread({
    required this.id,
    required this.userId,
    required this.artisanId,
    required this.lastMessage,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
    this.artisanName,
    this.artisanPhotoUrl,
  });

  final String id;
  final String userId;
  final String artisanId;
  final String lastMessage;
  final DateTime updatedAt;
  final String? userName;
  final String? userPhotoUrl;
  final String? artisanName;
  final String? artisanPhotoUrl;

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
      userName: (json['userName'] ?? json['user_name'])?.toString(),
      userPhotoUrl:
          (json['userPhotoUrl'] ?? json['user_photo_url'])?.toString(),
      artisanName: (json['artisanName'] ?? json['artisan_name'])?.toString(),
      artisanPhotoUrl:
          (json['artisanPhotoUrl'] ?? json['artisan_photo_url'])?.toString(),
    );
  }

  ChatThread copyWith({
    String? id,
    String? userId,
    String? artisanId,
    String? lastMessage,
    DateTime? updatedAt,
    String? userName,
    String? userPhotoUrl,
    String? artisanName,
    String? artisanPhotoUrl,
  }) {
    return ChatThread(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      artisanId: artisanId ?? this.artisanId,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      artisanName: artisanName ?? this.artisanName,
      artisanPhotoUrl: artisanPhotoUrl ?? this.artisanPhotoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artisan_id': artisanId,
      'last_message': lastMessage,
      'updated_at': updatedAt.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (userPhotoUrl != null) 'user_photo_url': userPhotoUrl,
      if (artisanName != null) 'artisan_name': artisanName,
      if (artisanPhotoUrl != null) 'artisan_photo_url': artisanPhotoUrl,
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
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String threadId;
  final String senderId;
  final MessageType type;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    MessageType? type,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
      updatedAt: DateTime.tryParse(
        (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
      ),
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
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
