import 'package:apptimtro/features/rooms/data/room_api.dart';
import 'package:apptimtro/features/rooms/data/room_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _RoomApi implements RoomApi {
  Map<String, Object?>? query;
  String? favorited;
  String? unfavorited;

  @override
  Future<List<Map<String, dynamic>>> search([
    Map<String, Object?> filters = const {},
  ]) async {
    query = filters;
    return [
      {
        'id': 'room-1',
        'title': 'Phòng',
        'description': '',
        'address': 'Quận 1',
        'latitude': 10.77,
        'longitude': 106.66,
        'price': 4000000,
        'area': 20,
        'totalRooms': 3,
        'availableRooms': 2,
        'electricityPrice': 3000,
        'waterPrice': 10000,
        'internetPrice': 100000,
        'deposit': 4000000,
        'status': 'AVAILABLE',
      },
    ];
  }

  @override
  Future<void> favorite(String id) async {
    favorited = id;
  }

  @override
  Future<void> unfavorite(String id) async {
    unfavorited = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'maps search API data to room domain models and forwards filters',
    () async {
      final api = _RoomApi();
      final repository = RoomRepository(api);
      final result = await repository.search({'minPrice': 1000000});

      expect(api.query, {'minPrice': 1000000});
      expect(result.single.id, 'room-1');
      expect(result.single.price, 4000000);
    },
  );

  test('forwards favorite and unfavorite actions to the API', () async {
    final api = _RoomApi();
    final repository = RoomRepository(api);

    await repository.favorite('room-1');
    await repository.unfavorite('room-1');

    expect(api.favorited, 'room-1');
    expect(api.unfavorited, 'room-1');
  });
}
