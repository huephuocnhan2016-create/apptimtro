import 'dart:io';

import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is! DioException) return error.toString();
  final status = error.response?.statusCode;
  final response = error.response?.data;
  final code = response is Map<String, dynamic> ? response['code'] : null;
  if (code == 'RATE_LIMITED') {
    return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
  }
  final message = response is Map<String, dynamic> ? response['message'] : null;
  if (message is String && message.isNotEmpty) return message;
  if (message is List && message.isNotEmpty) return message.join(', ');
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'Kết nối máy chủ quá thời gian. Vui lòng thử lại.';
  }
  if (error.type == DioExceptionType.connectionError) {
    return 'Không kết nối được máy chủ. Hãy kiểm tra máy chủ API đang chạy.';
  }
  if (error.type == DioExceptionType.unknown &&
      error.error is SocketException) {
    return 'Không có kết nối mạng. Vui lòng kiểm tra Internet.';
  }
  return switch (status) {
    401 => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu yêu cầu.',
    409 => 'Dữ liệu đã thay đổi. Vui lòng thử lại.',
    422 => 'Thông tin nhập chưa hợp lệ.',
    429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
    500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
    _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
  };
}
