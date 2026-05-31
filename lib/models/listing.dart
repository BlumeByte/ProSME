class Listing {
  const Listing({
    required this.id,
    required this.artisanId,
    this.artisanName,
    this.artisanPhotoUrl,
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
  final String? artisanName;
  final String? artisanPhotoUrl;
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
    final artisanRaw = json['artisan'];
    final artisanData = artisanRaw is Map
        ? Map<String, dynamic>.from(artisanRaw)
        : null;

    return Listing(
      id: (json['id'] ?? '') as String,
      artisanId: (json['artisanId'] ?? json['artisan_id'] ?? '') as String,
      artisanName: (json['artisanName'] ?? json['artisan_name'] ?? artisanData?['full_name'] ?? artisanData?['name']) as String?,
      artisanPhotoUrl: (json['artisanPhotoUrl'] ??
              json['artisan_photo_url'] ??
              artisanData?['avatar_url']) as String?,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      priceMin: ((json['priceMin'] ?? json['price_min'] ?? 0) as num).toDouble(),
      priceMax: ((json['priceMax'] ?? json['price_max'] ?? 0) as num).toDouble(),
      images: List<String>.from((json['images'] ?? const <dynamic>[]) as List<dynamic>),
      location: (json['location'] ?? '') as String,
      verifiedOnly: (json['verifiedOnly'] ?? json['verified_only'] ?? false) as bool,
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'artisanPhotoUrl': artisanPhotoUrl,
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
