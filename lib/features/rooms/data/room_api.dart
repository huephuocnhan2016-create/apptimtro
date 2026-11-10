import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class RoomApi {
  RoomApi(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> search([
    Map<String, Object?> query = const {},
  ]) async => _list(
    await _client.dio.get<dynamic>('/rooms/search', queryParameters: query),
  );

  Future<List<Map<String, dynamic>>> nearby({
    required double latitude,
    required double longitude,
    double radius = 5,
  }) async => _list(
    await _client.dio.get<dynamic>(
      '/rooms/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      },
    ),
  );

  Future<Map<String, dynamic>> get(String id) async =>
      (await _client.dio.get<Map<String, dynamic>>('/rooms/$id')).data!;

  Future<List<Map<String, dynamic>>> myRooms() async =>
      _list(await _client.dio.get<dynamic>('/rooms/my'));

  Future<List<Map<String, dynamic>>> favorites() async =>
      _list(await _client.dio.get<dynamic>('/users/me/favorites'));

  Future<void> favorite(String id) =>
      _client.dio.post<void>('/rooms/$id/favorite');

  Future<void> unfavorite(String id) =>
      _client.dio.delete<void>('/rooms/$id/favorite');

  Future<List<Map<String, dynamic>>> reviews(String id) async =>
      _list(await _client.dio.get<dynamic>('/rooms/$id/reviews'));

  Future<void> submitReview(
    String id, {
    required int rating,
    String? comment,
  }) => _client.dio.post<void>(
    '/rooms/$id/reviews',
    data: {'rating': rating, 'comment': ?comment},
  );

  Future<Map<String, dynamic>> create(Map<String, Object?> data) async =>
      (await _client.dio.post<Map<String, dynamic>>(
        '/rooms',
        data: data,
      )).data!;

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, Object?> data,
  ) async => (await _client.dio.put<Map<String, dynamic>>(
    '/rooms/$id',
    data: data,
  )).data!;

  Future<void> delete(String id) => _client.dio.delete<void>('/rooms/$id');

  Future<void> setAvailability(String id, int availableRooms) =>
      _client.dio.patch<void>(
        '/rooms/$id/availability',
        data: {'availableRooms': availableRooms},
      );

  Future<void> uploadImage(String id, String path) async {
    final body = FormData.fromMap({
      'image': await MultipartFile.fromFile(path),
    });
    await _client.dio.post<void>('/rooms/$id/images', data: body);
  }

  Future<void> removeImage(String id, String imageId) =>
      _client.dio.delete<void>('/rooms/$id/images/$imageId');

  List<Map<String, dynamic>> _list(Response<dynamic> response) {
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid room list response.');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }
}
