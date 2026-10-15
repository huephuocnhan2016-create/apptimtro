import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/call_session.dart';

class CallApi {
  CallApi(this._client);

  final ApiClient _client;

  Future<CallSession> create(String roomId) async => _session(
    await _client.dio.post<Map<String, dynamic>>(
      '/calls',
      data: {'roomId': roomId},
    ),
  );

  Future<CallSession> get(String id) async =>
      _session(await _client.dio.get<Map<String, dynamic>>('/calls/$id'));

  Future<CallSession> accept(String id) async => _session(
    await _client.dio.post<Map<String, dynamic>>('/calls/$id/accept'),
  );

  Future<void> reject(String id) => _client.dio.post<void>('/calls/$id/reject');
  Future<void> end(String id) => _client.dio.post<void>('/calls/$id/end');

  Future<List<CallSession>> history() async {
    final response = await _client.dio.get<dynamic>('/calls');
    final value = response.data;
    if (value is! List) {
      throw const FormatException('Invalid call history response.');
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(CallSession.fromJson)
        .toList();
  }

  CallSession _session(Response<Map<String, dynamic>> response) =>
      CallSession.fromJson(response.data!);
}
