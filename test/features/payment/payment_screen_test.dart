import 'package:apptimtro/core/providers.dart';
import 'package:apptimtro/features/payment/data/payment_api.dart';
import 'package:apptimtro/features/payment/domain/payment_order.dart';
import 'package:apptimtro/features/payment/presentation/payment_screen.dart';
import 'package:apptimtro/features/rooms/domain/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePaymentApi implements PaymentApi {
  _FakePaymentApi({this.result});

  final PaymentResult? result;

  @override
  Future<PaymentOrder> createOrder(String roomId) async => const PaymentOrder(
    txnRef: '20261109ABCD',
    payUrl: 'http://10.0.2.2:3300/api/payment/dev/checkout/20261109ABCD',
    amount: 1400000,
    status: 'PENDING',
    orderInfo: 'Dat coc tro tot 20261109ABCD',
  );

  @override
  Future<PaymentResult> status(String txnRef) async =>
      result ??
      const PaymentResult(
        status: 'PENDING',
        txnRef: '20261109ABCD',
        amount: 1400000,
        bankName: 'VNPAY',
        transactionNo: null,
        responseCode: null,
        payDate: null,
        message: 'Giao dịch chưa hoàn tất',
      );
}

Room get _room => const Room(
  id: 'room-id',
  title: 'Phòng trọ Minh Thạnh',
  description: '',
  address: 'TP.HCM',
  latitude: null,
  longitude: null,
  price: 2500000,
  area: 30,
  totalRooms: 5,
  availableRooms: 3,
  electricityPrice: 4000,
  waterPrice: 0,
  internetPrice: 0,
  deposit: 1400000,
  status: 'AVAILABLE',
);

Future<void> _pump(WidgetTester tester, PaymentApi api) => tester.pumpWidget(
  ProviderScope(
    overrides: [paymentApiProvider.overrideWithValue(api)],
    child: MaterialApp(theme: ThemeData.light(), home: PaymentScreen(room: _room)),
  ),
);

void main() {
  testWidgets('shows the portal checkout card before paying', (tester) async {
    await _pump(tester, _FakePaymentApi());
    await tester.pumpAndSettle();

    expect(find.text('VNPAY'), findsOne);
    expect(find.text('SANDBOX'), findsOne);
    expect(find.text('Thông tin thanh toán'), findsOne);
    expect(find.text('1.400.000 VND'), findsOne);
    expect(find.text('Dat coc tro tot 20261109ABCD'), findsOne);
    expect(find.text('Cổng thanh toán VNPAY'), findsOne);
    expect(find.text('Thanh toán ngay'), findsOne);
    expect(find.byIcon(Icons.qr_code), findsNothing);
  });

  testWidgets('renders the VNPay result once the order is paid', (tester) async {
    await _pump(
      tester,
      _FakePaymentApi(
        result: const PaymentResult(
          status: 'PAID',
          txnRef: '20261109ABCD',
          amount: 1400000,
          bankName: 'VNPAY',
          transactionNo: '12345',
          responseCode: '00',
          payDate: '20261109102708',
          message: 'Giao dịch thành công',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Trạng thái giao dịch'), findsOne);
    expect(find.text('Giao dịch thành công'), findsOne);
    expect(find.text('Mã 00'), findsOne);
    expect(find.text('12345'), findsOne);
    expect(find.text('09/11/2026 10:27:08'), findsOne);
    expect(find.text('Thanh toán ngay'), findsNothing);
  });
}
