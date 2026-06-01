class JobMessage {
  const JobMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime createdAt;
}
