import '../domain/room.dart';
import '../domain/room_review.dart';
import 'room_api.dart';

class RoomRepository {
  RoomRepository(this.api);

  final RoomApi api;

  Future<List<Room>> search([Map<String, Object?> query = const {}]) async =>
      (await api.search(query)).map(Room.fromJson).toList();

  Future<List<Room>> nearby({
    required double latitude,
    required double longitude,
    double radius = 5,
  }) async => (await api.nearby(
    latitude: latitude,
    longitude: longitude,
    radius: radius,
  )).map(Room.fromJson).toList();

  Future<Room> get(String id) async => Room.fromJson(await api.get(id));

  Future<List<Room>> myRooms() async =>
      (await api.myRooms()).map(Room.fromJson).toList();

  Future<List<Room>> favorites() async =>
      (await api.favorites()).map(Room.fromJson).toList();

  Future<void> favorite(String id) => api.favorite(id);
  Future<void> unfavorite(String id) => api.unfavorite(id);
  Future<List<RoomReview>> reviews(String id) async =>
      (await api.reviews(id)).map(RoomReview.fromJson).toList();
  Future<void> submitReview(String id, {required int rating, String? comment}) =>
      api.submitReview(id, rating: rating, comment: comment);
  Future<Room> create(Map<String, Object?> data) async =>
      Room.fromJson(await api.create(data));
  Future<Room> update(String id, Map<String, Object?> data) async =>
      Room.fromJson(await api.update(id, data));
  Future<void> delete(String id) => api.delete(id);
  Future<void> setAvailability(String id, int count) =>
      api.setAvailability(id, count);
  Future<void> uploadImage(String id, String path) => api.uploadImage(id, path);
}
