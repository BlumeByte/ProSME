class Job {
  final String id;
  final String title;
  final String description;
  final String location;
  final double budget;
  final String createdBy;
  final String status;
  final List<String> images;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.budget,
    required this.createdBy,
    required this.status,
    required this.images,
    required this.createdAt,
  });
}
