import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class ChatApi {
  ChatApi(this._client);

  final ApiClient _client;

  Future<String> firebaseToken() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/auth/firebase-token',
    );
    return response.data!['firebaseToken'] as String;
  }

  Future<String> openConversation(String roomId) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/chat/conversations',
      data: {'roomId': roomId},
    );
    return response.data!['id'] as String;
  }

  Future<List<Map<String, dynamic>>> conversations() async =>
      _list(await _client.dio.get<dynamic>('/chat/conversations'));

  List<Map<String, dynamic>> _list(Response<dynamic> response) {
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid conversation list response.');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }
}
