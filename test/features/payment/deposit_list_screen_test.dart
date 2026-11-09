import 'package:apptimtro/core/providers.dart';
import 'package:apptimtro/features/payment/data/payment_api.dart';
import 'package:apptimtro/features/payment/domain/payment_order.dart';
import 'package:apptimtro/features/payment/presentation/deposit_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakePaymentApi implements PaymentApi {
  _FakePaymentApi({List<RoomDeposit> held = const [], this.failure})
    : held = List.of(held);

  final List<RoomDeposit> held;
  final Object? failure;
  final List<String> cancelledTxnRefs = [];
  Object? cancelFailure;

  @override
  Future<PaymentOrder> createOrder(
    String roomId, {
    String gateway = kDefaultGateway,
  }) async => throw UnimplementedError();

  @override
  Future<PaymentResult> status(String txnRef) async =>
      throw UnimplementedError();

  @override
  Future<PaymentResult> cancel(String txnRef) async {
    if (cancelFailure != null) throw cancelFailure!;
    cancelledTxnRefs.add(txnRef);
    held.removeWhere((deposit) => deposit.txnRef == txnRef);
    return const PaymentResult(
      status: 'CANCELLED',
      txnRef: 'a1b2',
      amount: 4000000,
      bankName: 'VNPAY',
      transactionNo: null,
      responseCode: '24',
      payDate: null,
      message: 'Giao dịch bị hủy',
    );
  }

  @override
  Future<List<RoomDeposit>> deposits() async {
    if (failure != null) throw failure!;
    return held;
  }
}

const _held = RoomDeposit(
  txnRef: 'a1b2',
  amount: 4000000,
  payDate: null,
  roomId: 'room-42',
  roomTitle: 'Phòng trọ Xuyên Mộc',
  roomAddress: 'Xã Xuyên Mộc, Thành phố Hồ Chí Minh',
);

Future<void> _pump(WidgetTester tester, PaymentApi api) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentApiProvider.overrideWithValue(api)],
      child: MaterialApp.router(
        theme: ThemeData.light(),
        routerConfig: GoRouter(
          initialLocation: '/deposits',
          routes: [
            GoRoute(
              path: '/deposits',
              builder: (_, _) => const DepositListScreen(),
            ),
            GoRoute(
              path: '/rooms/:id',
              builder: (_, _) => const Scaffold(body: Text('detail')),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lists the rooms the student is holding a deposit on', (
    tester,
  ) async {
    await _pump(tester, _FakePaymentApi(held: const [_held]));
    await tester.pumpAndSettle();

    expect(find.text('Phòng đã đặt cọc'), findsOneWidget);
    expect(find.text('Phòng trọ Xuyên Mộc'), findsOneWidget);
    expect(find.textContaining('Cọc 4.000.000 đ'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('says so when there is nothing deposited', (tester) async {
    await _pump(tester, _FakePaymentApi());
    await tester.pumpAndSettle();

    expect(find.text('Bạn chưa đặt cọc phòng nào.'), findsOneWidget);
  });

  testWidgets('reports a failed list load', (tester) async {
    await _pump(tester, _FakePaymentApi(failure: Exception('boom')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được danh sách đặt cọc'), findsOne);
  });

  testWidgets('cancels a deposit from the list and refreshes it', (
    tester,
  ) async {
    final api = _FakePaymentApi(held: const [_held]);
    await _pump(tester, api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hủy cọc'));
    await tester.pumpAndSettle();
    expect(
      find.text('Phòng sẽ được mở lại cho người khác đặt cọc.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Hủy cọc'));
    await tester.pumpAndSettle();

    expect(api.cancelledTxnRefs, ['a1b2']);
    expect(find.text('Đã hủy đặt cọc.'), findsOneWidget);
    expect(find.text('Bạn chưa đặt cọc phòng nào.'), findsOneWidget);
  });

  testWidgets('keeps the deposit listed when the cancel is refused', (
    tester,
  ) async {
    final api = _FakePaymentApi(held: const [_held])
      ..cancelFailure = Exception('no refund api');
    await _pump(tester, api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hủy cọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy cọc'));
    await tester.pumpAndSettle();

    expect(find.text('Phòng trọ Xuyên Mộc'), findsOneWidget);
    expect(find.textContaining('Không hủy được đặt cọc'), findsOneWidget);
  });
}
