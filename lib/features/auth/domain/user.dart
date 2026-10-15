import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole {
  @JsonValue('STUDENT')
  student,
  @JsonValue('LANDLORD')
  landlord,
  @JsonValue('ADMIN')
  admin,
}

@JsonSerializable()
class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.email,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String phone;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final UserRole role;
  final bool isVerified;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
