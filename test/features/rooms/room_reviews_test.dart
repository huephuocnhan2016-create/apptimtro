import 'package:apptimtro/core/providers.dart';
import 'package:apptimtro/features/rooms/data/room_repository.dart';
import 'package:apptimtro/features/rooms/domain/room.dart';
import 'package:apptimtro/features/rooms/domain/room_review.dart';
import 'package:apptimtro/features/rooms/presentation/room_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.room, this.reviewList);

  final Room room;
  final List<RoomReview> reviewList;
  final List<(int, String?)> submitted = [];

  @override
  Future<Room> get(String id) async => room;

  @override
  Future<List<RoomReview>> reviews(String id) async => reviewList;

  @override
  Future<void> submitReview(
    String id, {
    required int rating,
    String? comment,
  }) async {
    submitted.add((rating, comment));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Không ảnh và không tọa độ: màn chi tiết khỏi gọi mạng cho ảnh và bản đồ.
Room _room({bool canReview = false}) => Room(
  id: 'room-1',
  title: 'Phòng trọ Quận 7',
  description: 'Gần đại học',
  address: 'Đường Nguyễn Văn Linh, Thành phố Hồ Chí Minh',
  latitude: null,
  longitude: null,
  price: 2500000,
  area: 25,
  totalRooms: 10,
  availableRooms: 4,
  electricityPrice: 4000,
  waterPrice: 20000,
  internetPrice: 0,
  deposit: 2500000,
  status: 'AVAILABLE',
  ratingAverage: canReview ? 4.5 : null,
  ratingCount: canReview ? 2 : 0,
  canReview: canReview,
);

Future<_FakeRoomRepository> _pump(
  WidgetTester tester,
  Room room,
  List<RoomReview> reviews,
) async {
  // ListView chỉ dựng phần nằm trong khung nhìn, mà khối đánh giá thì ở cuối
  // trang — mở cao khung nhìn để mọi mục đều có trong cây widget.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _FakeRoomRepository(room, reviews);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [roomRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: RoomDetailScreen(roomId: room.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

RoomReview _review(String author, int rating, String comment) => RoomReview(
  id: author,
  rating: rating,
  author: author,
  comment: comment,
  createdAt: DateTime(2026, 11, 11),
);

void main() {
  testWidgets('hides the review button from someone who has not paid a deposit', (
    tester,
  ) async {
    await _pump(tester, _room(), const []);

    expect(find.text('Chưa có đánh giá'), findsOneWidget);
    expect(
      find.text('Chỉ sinh viên đã đặt cọc phòng này mới bình luận và đánh giá được.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.rate_review_outlined), findsNothing);
  });

  testWidgets('lists what deposited students wrote', (tester) async {
    await _pump(tester, _room(canReview: true), [
      _review('Trần B', 5, 'Phòng sạch, chủ dễ tính'),
      _review('Lê A', 4, 'Yên tĩnh'),
    ]);

    expect(find.text('4,5 / 5 · 2 lượt'), findsOneWidget);
    expect(find.text('Trần B'), findsOneWidget);
    expect(find.text('Phòng sạch, chủ dễ tính'), findsOneWidget);
    expect(find.text('Yên tĩnh'), findsOneWidget);
    expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);
  });

  testWidgets('sends the chosen stars and the comment', (tester) async {
    final repository = await _pump(tester, _room(canReview: true), const []);

    await tester.tap(find.byIcon(Icons.rate_review_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Đánh giá phòng'), findsOneWidget);
    // Nút sao bị chặn nên "Gửi đánh giá" chưa bấm được.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Gửi đánh giá')).enabled, isFalse);

    await tester.tap(find.byTooltip('4 sao'));
    await tester.enterText(find.byType(TextField), '  máy lạnh yếu  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đánh giá'));
    await tester.pumpAndSettle();

    expect(repository.submitted, [(4, 'máy lạnh yếu')]);
  });
}
