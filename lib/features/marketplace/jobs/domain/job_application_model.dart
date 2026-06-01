class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.artisanId,
    required this.message,
    required this.proposedPrice,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String artisanId;
  final String message;
  final double proposedPrice;
  final String status;
  final DateTime createdAt;
}
