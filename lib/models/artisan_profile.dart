import '../config/constants.dart';

class ArtisanProfile {
  const ArtisanProfile({
    required this.userId,
    required this.verifiedStatus,
    required this.nationalIdUrl,
    required this.momoNumber,
    required this.location,
    required this.categories,
    required this.bio,
    required this.ratingSummary,
  });

  final String userId;
  final VerificationStatus verifiedStatus;
  final String nationalIdUrl;
  final String momoNumber;
  final String location;
  final List<String> categories;
  final String bio;
  final double ratingSummary;

  factory ArtisanProfile.fromJson(Map<String, dynamic> json) {
    return ArtisanProfile(
      userId: json['userId'] as String,
      verifiedStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == json['verifiedStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      nationalIdUrl: json['nationalIdUrl'] as String,
      momoNumber: json['momoNumber'] as String,
      location: json['location'] as String,
      categories: List<String>.from(json['categories'] as List<dynamic>),
      bio: json['bio'] as String,
      ratingSummary: (json['ratingSummary'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'verifiedStatus': verifiedStatus.name,
      'nationalIdUrl': nationalIdUrl,
      'momoNumber': momoNumber,
      'location': location,
      'categories': categories,
      'bio': bio,
      'ratingSummary': ratingSummary,
    };
  }
}
