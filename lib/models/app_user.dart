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
    this.gender = '',
    this.dateOfBirth,
    this.isBusy = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.emailNotifications = true,
    this.phoneNotifications = true,
    this.blockedEmailNotificationTypes = const <String>{},
    this.blockedPhoneNotificationTypes = const <String>{},
    this.appLanguage = 'English',
    this.currencyCode = 'GHS',
    this.verificationStatus = VerificationStatus.pending,
    this.twoFactorEnabled = false,
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
  final String gender;
  final DateTime? dateOfBirth;
  final bool isBusy;
  final bool emailVerified;
  final bool phoneVerified;
  final bool emailNotifications;
  final bool phoneNotifications;
  final Set<String> blockedEmailNotificationTypes;
  final Set<String> blockedPhoneNotificationTypes;
  final String appLanguage;
  final String currencyCode;
  final VerificationStatus verificationStatus;
  final bool twoFactorEnabled;
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
    String? gender,
    DateTime? dateOfBirth,
    bool? isBusy,
    bool? emailVerified,
    bool? phoneVerified,
    bool? emailNotifications,
    bool? phoneNotifications,
    Set<String>? blockedEmailNotificationTypes,
    Set<String>? blockedPhoneNotificationTypes,
    String? appLanguage,
    String? currencyCode,
    VerificationStatus? verificationStatus,
    bool? twoFactorEnabled,
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
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isBusy: isBusy ?? this.isBusy,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      phoneNotifications: phoneNotifications ?? this.phoneNotifications,
      blockedEmailNotificationTypes:
          blockedEmailNotificationTypes ?? this.blockedEmailNotificationTypes,
      blockedPhoneNotificationTypes:
          blockedPhoneNotificationTypes ?? this.blockedPhoneNotificationTypes,
      appLanguage: appLanguage ?? this.appLanguage,
      currencyCode: currencyCode ?? this.currencyCode,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
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
      gender: (json['gender'] as String?) ?? '',
      dateOfBirth: DateTime.tryParse((json['dateOfBirth'] ?? '').toString()),
      isBusy: (json['isBusy'] as bool?) ?? false,
      emailVerified: (json['emailVerified'] as bool?) ?? false,
      phoneVerified: (json['phoneVerified'] as bool?) ?? false,
      emailNotifications: (json['emailNotifications'] as bool?) ?? true,
      phoneNotifications: (json['phoneNotifications'] as bool?) ?? true,
      blockedEmailNotificationTypes:
          ((json['blockedEmailNotificationTypes'] as List?) ?? const [])
              .map((item) => item.toString())
              .toSet(),
      blockedPhoneNotificationTypes:
          ((json['blockedPhoneNotificationTypes'] as List?) ?? const [])
              .map((item) => item.toString())
              .toSet(),
      appLanguage: (json['appLanguage'] as String?) ?? 'English',
      currencyCode: (json['currencyCode'] as String?) ?? 'GHS',
      verificationStatus: VerificationStatus.values.firstWhere(
        (status) => status.name == json['verificationStatus'],
        orElse: () => VerificationStatus.pending,
      ),
      twoFactorEnabled: (json['twoFactorEnabled'] as bool?) ?? false,
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
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'isBusy': isBusy,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'emailNotifications': emailNotifications,
      'phoneNotifications': phoneNotifications,
      'blockedEmailNotificationTypes': blockedEmailNotificationTypes.toList()
        ..sort(),
      'blockedPhoneNotificationTypes': blockedPhoneNotificationTypes.toList()
        ..sort(),
      'appLanguage': appLanguage,
      'currencyCode': currencyCode,
      'verificationStatus': verificationStatus.name,
      'twoFactorEnabled': twoFactorEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
