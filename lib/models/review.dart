class Review {
  const Review({
    required this.id,
    required this.targetId,
    required this.userId,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String targetId;
  final String userId;
  final int stars;
  final String comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      targetId: json['targetId'] as String,
      userId: json['userId'] as String,
      stars: json['stars'] as int,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetId': targetId,
      'userId': userId,
      'stars': stars,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
