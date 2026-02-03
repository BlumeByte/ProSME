import '../config/constants.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final UserRole role;
  final String name;
  final String phone;
  final String email;
  final String photoUrl;
  final DateTime createdAt;

  AppUser copyWith({
    UserRole? role,
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
  }) {
    return AppUser(
      id: id,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
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
      phone: json['phone'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'name': name,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
