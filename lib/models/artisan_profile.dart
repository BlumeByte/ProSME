import '../config/constants.dart';

class ArtisanProfile {
  const ArtisanProfile({
    required this.userId,
    this.role = UserRole.artisan,
    this.phone = '',
    required this.verifiedStatus,
    required this.nationalIdUrl,
    this.nationalIdBackUrl = '',
    required this.momoNumber,
    required this.location,
    required this.categories,
    required this.bio,
    required this.ratingSummary,
  });

  final String userId;
  final UserRole role;
  final String phone;
  final VerificationStatus verifiedStatus;
  final String nationalIdUrl;
  final String nationalIdBackUrl;
  final String momoNumber;
  final String location;
  final List<String> categories;
  final String bio;
  final double ratingSummary;

  factory ArtisanProfile.fromJson(Map<String, dynamic> json) {
    return ArtisanProfile(
      userId: json['userId'] as String,
      role: UserRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => UserRole.artisan,
      ),
      phone: (json['phone'] ?? '').toString(),
      verifiedStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == json['verifiedStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      nationalIdUrl: json['nationalIdUrl'] as String,
      nationalIdBackUrl: (json['nationalIdBackUrl'] ?? '').toString(),
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
      'role': role.name,
      'phone': phone,
      'verifiedStatus': verifiedStatus.name,
      'nationalIdUrl': nationalIdUrl,
      'nationalIdBackUrl': nationalIdBackUrl,
      'momoNumber': momoNumber,
      'location': location,
      'categories': categories,
      'bio': bio,
      'ratingSummary': ratingSummary,
    };
  }
}
