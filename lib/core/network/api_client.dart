import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';

class ApiClient {
  Future<Map<String, dynamic>>? _refreshing;

  ApiClient(this.storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isPublicAuthRoute = const {
            '/auth/send-otp',
            '/auth/verify-otp',
            '/auth/register',
            '/auth/login',
            '/auth/refresh',
          }.contains(request.path);
          if (error.response?.statusCode != 401 ||
              isPublicAuthRoute ||
              request.extra['retried'] == true) {
            handler.next(error);
            return;
          }

          try {
            final data = await _refreshTokens();
            final access = data['accessToken'] as String;
            final refresh = data['refreshToken'] as String;
            await storage.saveTokens(
              accessToken: access,
              refreshToken: refresh,
            );
            request
              ..headers['Authorization'] = 'Bearer $access'
              ..extra['retried'] = true;
            handler.resolve(await dio.fetch<dynamic>(request));
          } on DioException catch (refreshError) {
            if (refreshError.response?.statusCode == 401 ||
                refreshError.response?.statusCode == 403) {
              await storage.clear();
            }
            handler.next(error);
          } on FormatException {
            await storage.clear();
            handler.next(error);
          } on StateError {
            await storage.clear();
            handler.next(error);
          } on TypeError {
            await storage.clear();
            handler.next(error);
          }
        },
        onResponse: (response, handler) {
          final body = response.data;
          if (body is Map<String, dynamic> &&
              body['success'] == true &&
              body.containsKey('data')) {
            response.data = body['data'];
          }
          handler.next(response);
        },
      ),
    );
  }

  final TokenStorage storage;
  late final Dio dio;

  Future<Map<String, dynamic>> _refreshTokens() {
    final activeRefresh = _refreshing;
    if (activeRefresh != null) return activeRefresh;
    final refresh = _fetchRefreshTokens();
    _refreshing = refresh;
    return refresh.whenComplete(() {
      _refreshing = null;
    });
  }

  Future<Map<String, dynamic>> _fetchRefreshTokens() async {
    final refreshToken = await storage.refreshToken;
    if (refreshToken == null) {
      throw StateError('No refresh token is stored.');
    }
    final response =
        await Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ).post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
    final envelope = response.data;
    final data = envelope is Map<String, dynamic> && envelope['success'] == true
        ? envelope['data']
        : envelope;
    if (data is! Map<String, dynamic> ||
        data['accessToken'] is! String ||
        data['refreshToken'] is! String) {
      throw const FormatException('Invalid refresh response.');
    }
    return data;
  }
}
