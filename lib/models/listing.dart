class Listing {
  const Listing({
    required this.id,
    required this.artisanId,
    required this.title,
    required this.description,
    required this.category,
    required this.priceMin,
    required this.priceMax,
    required this.images,
    required this.location,
    required this.verifiedOnly,
    required this.createdAt,
  });

  final String id;
  final String artisanId;
  final String title;
  final String description;
  final String category;
  final double priceMin;
  final double priceMax;
  final List<String> images;
  final String location;
  final bool verifiedOnly;
  final DateTime createdAt;

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      artisanId: json['artisanId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priceMin: (json['priceMin'] as num).toDouble(),
      priceMax: (json['priceMax'] as num).toDouble(),
      images: List<String>.from(json['images'] as List<dynamic>),
      location: json['location'] as String,
      verifiedOnly: json['verifiedOnly'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artisanId': artisanId,
      'title': title,
      'description': description,
      'category': category,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'images': images,
      'location': location,
      'verifiedOnly': verifiedOnly,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
