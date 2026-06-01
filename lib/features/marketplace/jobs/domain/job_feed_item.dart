class JobFeedItem {
  JobFeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.budget,
    required this.createdBy,
    required this.createdAt,
    required this.images,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final double budget;
  final String createdBy;
  final DateTime createdAt;
  final List<String> images;
}
