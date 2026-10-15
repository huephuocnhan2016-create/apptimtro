import 'package:dio/dio.dart';

import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository(this.api, this.storage);

  final AuthApi api;
  final TokenStorage storage;

  Future<String?> sendOtp(String phone, UserRole role) =>
      api.sendOtp(phone, role);

  Future<String> verifyOtp(String phone, String otp) =>
      api.verifyOtp(phone, otp);

  Future<AppUser> register({
    required String phone,
    required String verificationToken,
    required UserRole role,
    String? fullName,
    String? email,
  }) async {
    final data = await api.register(
      phone: phone,
      verificationToken: verificationToken,
      role: role,
      fullName: fullName,
      email: email,
    );
    return _saveSession(data);
  }

  Future<AppUser> login({
    required String phone,
    required String verificationToken,
  }) async => _saveSession(
    await api.login(phone: phone, verificationToken: verificationToken),
  );

  Future<AppUser?> restoreSession() async {
    if (await storage.accessToken == null) return null;
    try {
      return await api.me();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await storage.clear();
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } on DioException {
      // Credentials must still be removed locally when the server is unavailable.
    } finally {
      await storage.clear();
    }
  }

  Future<AppUser> _saveSession(Map<String, dynamic> data) async {
    await storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }
}
