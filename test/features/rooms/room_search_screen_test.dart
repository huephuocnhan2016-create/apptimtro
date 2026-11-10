import 'package:apptimtro/core/providers.dart';
import 'package:apptimtro/features/map/domain/location_service.dart';
import 'package:apptimtro/features/rooms/data/room_repository.dart';
import 'package:apptimtro/features/rooms/domain/room.dart';
import 'package:apptimtro/features/rooms/presentation/room_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.rooms);

  final List<Room> rooms;
  final List<Map<String, Object?>> queries = [];

  @override
  Future<List<Room>> search([Map<String, Object?> query = const {}]) async {
    queries.add(query);
    final text = query['query'] as String?;
    final min = double.tryParse('${query['minPrice'] ?? ''}');
    return rooms
        .where((room) => text == null || room.title.contains(text))
        .where((room) => min == null || room.price >= min)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeLocationService implements LocationService {
  static final position = Position(
    latitude: 10.77,
    longitude: 106.66,
    timestamp: DateTime(2026, 11, 10),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<Position> currentPosition() async => position;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Room _room(String title, double price) => Room(
  id: title,
  title: title,
  description: '',
  address: 'Xã Xuyên Mộc, Thành phố Hồ Chí Minh',
  latitude: 10.5,
  longitude: 107.0,
  price: price,
  area: 25,
  totalRooms: 10,
  availableRooms: 4,
  electricityPrice: 4000,
  waterPrice: 20000,
  internetPrice: 0,
  deposit: 0,
  status: 'AVAILABLE',
);

Future<_FakeRoomRepository> _pump(WidgetTester tester, List<Room> rooms) async {
  final repository = _FakeRoomRepository(rooms);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const RoomSearchScreen())],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomRepositoryProvider.overrideWithValue(repository),
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  const cheap = 'Phòng rẻ';
  const pricey = 'Phòng đắt';

  testWidgets('nhấn Tìm trên bàn phím gửi từ khóa xuống repository', (
    tester,
  ) async {
    final repository = await _pump(tester, [
      _room(cheap, 1000000),
      _room(pricey, 5000000),
    ]);

    await tester.enterText(find.byType(TextField).first, 'đắt');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last['query'], 'đắt');
    expect(find.text(cheap), findsNothing);
    expect(find.text(pricey), findsOneWidget);
  });

  testWidgets('từ khóa không khớp hiện thông báo rỗng', (tester) async {
    await _pump(tester, [_room(cheap, 1000000)]);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy phòng phù hợp.'), findsOneWidget);
  });

  testWidgets('Áp dụng trong sheet lọc đóng sheet và gửi bộ lọc', (
    tester,
  ) async {
    final repository = await _pump(tester, [
      _room(cheap, 1000000),
      _room(pricey, 5000000),
    ]);

    await tester.tap(find.byTooltip('Lọc phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc phòng'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Giá từ (đ)'),
      '2.000.000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(repository.queries.last['minPrice'], '2000000');
    expect(find.text(cheap), findsNothing);
    expect(find.text(pricey), findsOneWidget);
  });

  testWidgets('lọc khoảng cách xin vị trí và badge chỉ tính bộ lọc', (
    tester,
  ) async {
    final repository = await _pump(tester, [
      _room(cheap, 1000000),
      _room(pricey, 5000000),
    ]);

    await tester.tap(find.byTooltip('Lọc phòng'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Khoảng cách tối đa (km)'),
      '5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
    await tester.pumpAndSettle();

    final query = repository.queries.last;
    expect(query['radius'], '5');
    expect(query['latitude'], 10.77);
    expect(query['longitude'], 106.66);
    expect(
      find.descendant(
        of: find.byTooltip('Lọc phòng'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Xóa lọc bỏ hết bộ lọc nhưng giữ kiểu sắp xếp', (tester) async {
    final repository = await _pump(tester, [
      _room(cheap, 1000000),
      _room(pricey, 5000000),
    ]);

    await tester.tap(find.byTooltip('Lọc phòng'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Giá từ (đ)'),
      '2.000.000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lọc phòng'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Xóa lọc'));
    await tester.pumpAndSettle();

    expect(repository.queries.last, {'sort': 'newest'});
    expect(find.text(cheap), findsOneWidget);
    expect(find.byTooltip('Lọc phòng'), findsOneWidget);
  });
}
