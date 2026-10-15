// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  id: json['id'] as String,
  phone: json['phone'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  isVerified: json['isVerified'] as bool,
  email: json['email'] as String?,
  fullName: json['fullName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'phone': instance.phone,
  'email': instance.email,
  'fullName': instance.fullName,
  'avatarUrl': instance.avatarUrl,
  'role': _$UserRoleEnumMap[instance.role]!,
  'isVerified': instance.isVerified,
};

const _$UserRoleEnumMap = {
  UserRole.student: 'STUDENT',
  UserRole.landlord: 'LANDLORD',
  UserRole.admin: 'ADMIN',
};
