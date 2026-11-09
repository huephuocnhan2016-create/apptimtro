import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Gom phần "bật busy → gọi API → báo lỗi → tắt busy" mà 4 màn đăng nhập/đăng
/// ký từng viết tay. Màn hình chỉ cần:
/// - `ref.watch(authControllerProvider).isLoading` để hiện vòng xoay,
/// - gọi hàm bên dưới; kết quả `null` nghĩa là lỗi → `showAuthError`.
final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Gửi OTP. Thành công trả record chứa mã dev (có thể null ở môi trường thật).
  Future<({String? devOtp})?> sendOtp(String phone, UserRole role) =>
      _run(() async => (devOtp: await _repository.sendOtp(phone, role)));

  /// Xác thực OTP, trả về verificationToken.
  Future<String?> verifyOtp(String phone, String otp) =>
      _run(() => _repository.verifyOtp(phone, otp));

  Future<AppUser?> login({
    required String phone,
    required String verificationToken,
  }) => _run(() async {
    final user = await _repository.login(
      phone: phone,
      verificationToken: verificationToken,
    );
    ref.read(currentUserProvider.notifier).setUser(user);
    return user;
  });

  Future<AppUser?> register({
    required String phone,
    required String verificationToken,
    required UserRole role,
    required String fullName,
    String? email,
  }) => _run(() async {
    final user = await _repository.register(
      phone: phone,
      verificationToken: verificationToken,
      role: role,
      fullName: fullName,
      email: email,
    );
    ref.read(currentUserProvider.notifier).setUser(user);
    return user;
  });

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await action();
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } on DioException catch (error, stack) {
      if (ref.mounted) state = AsyncError(AuthException.fromDio(error), stack);
      return null;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return null;
    }
  }
}

/// Hiện lỗi gần nhất của [authControllerProvider] (nếu có) bằng SnackBar.
void showAuthError(BuildContext context, WidgetRef ref) {
  final error = ref.read(authControllerProvider).error;
  if (error == null) return;
  final message = error is AuthException
      ? error.message
      : apiErrorMessage(error);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
