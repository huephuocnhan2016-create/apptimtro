import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../domain/user.dart';

Map<String, Object?>? _optionalFields(String? fullName, String? email) {
  final fields = <String, Object?>{};
  if (fullName != null) fields['fullName'] = fullName;
  if (email != null) fields['email'] = email;
  return fields.isEmpty ? null : fields;
}

class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<String?> sendOtp(String phone, UserRole role) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/send-otp',
      data: {'phone': phone, 'role': role.name.toUpperCase()},
    );
    return response.data?['devOtp'] as String?;
  }

  Future<String> verifyOtp(String phone, String otp) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    return response.data!['verificationToken'] as String;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String verificationToken,
    required UserRole role,
    String? fullName,
    String? email,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'phone': phone,
        'verificationToken': verificationToken,
        'role': role.name.toUpperCase(),
        ...?_optionalFields(fullName, email),
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String verificationToken,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'phone': phone, 'verificationToken': verificationToken},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return response.data!;
  }

  Future<void> logout() async {
    await _client.dio.post<void>('/auth/logout');
  }

  Future<AppUser> me() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/auth/me');
    return AppUser.fromJson(response.data!);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  static AuthException fromDio(DioException error) {
    // Không có phản hồi = chưa tới được máy chủ (máy chủ tắt, sai địa chỉ,
    // hết thời gian). Dùng thông báo chi tiết thay vì "kiểm tra Internet".
    if (error.response == null) return AuthException(apiErrorMessage(error));
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String) {
        return AuthException(_friendly(message, error.response?.statusCode));
      }
      if (message is List && message.isNotEmpty) {
        return AuthException(
          _friendly(message.join(', '), error.response?.statusCode),
        );
      }
    }
    return AuthException(_friendly(null, error.response?.statusCode));
  }

  static String _friendly(String? message, int? status) {
    if (message != null && message.isNotEmpty) return message;
    return switch (status) {
      401 => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu yêu cầu.',
      409 => 'Dữ liệu đã thay đổi. Vui lòng thử lại.',
      422 => 'Thông tin nhập chưa hợp lệ.',
      429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
      500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
      null => 'Không có kết nối mạng. Vui lòng kiểm tra Internet.',
      _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
    };
  }
}
