import '../config/constants.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    this.fullName = '',
    required this.phone,
    required this.email,
    required this.photoUrl,
    this.country = 'Ghana',
    this.countryCode = '+233',
    this.description = '',
    this.isBusy = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.verificationStatus = VerificationStatus.pending,
    required this.createdAt,
  });

  final String id;
  final UserRole role;
  final String name;
  final String fullName;
  final String phone;
  final String email;
  final String photoUrl;
  final String country;
  final String countryCode;
  final String description;
  final bool isBusy;
  final bool emailVerified;
  final bool phoneVerified;
  final VerificationStatus verificationStatus;
  final DateTime createdAt;

  AppUser copyWith({
    UserRole? role,
    String? name,
    String? fullName,
    String? phone,
    String? email,
    String? photoUrl,
    String? country,
    String? countryCode,
    String? description,
    bool? isBusy,
    bool? emailVerified,
    bool? phoneVerified,
    VerificationStatus? verificationStatus,
  }) {
    return AppUser(
      id: id,
      role: role ?? this.role,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      description: description ?? this.description,
      isBusy: isBusy ?? this.isBusy,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      role: UserRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => UserRole.customer,
      ),
      name: json['name'] as String,
      fullName: (json['fullName'] as String?) ?? '',
      phone: json['phone'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String,
      country: (json['country'] as String?) ?? 'Ghana',
      countryCode: (json['countryCode'] as String?) ?? '+233',
      description: (json['description'] as String?) ?? '',
      isBusy: (json['isBusy'] as bool?) ?? false,
      emailVerified: (json['emailVerified'] as bool?) ?? false,
      phoneVerified: (json['phoneVerified'] as bool?) ?? false,
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == json['verificationStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'name': name,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'country': country,
      'countryCode': countryCode,
      'description': description,
      'isBusy': isBusy,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'verificationStatus': verificationStatus.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
