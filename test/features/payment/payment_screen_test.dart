import 'package:apptimtro/core/providers.dart';
import 'package:apptimtro/features/payment/data/payment_api.dart';
import 'package:apptimtro/features/payment/domain/payment_order.dart';
import 'package:apptimtro/features/payment/presentation/payment_screen.dart';
import 'package:apptimtro/features/rooms/domain/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePaymentApi implements PaymentApi {
  _FakePaymentApi({this.result});

  final PaymentResult? result;

  /// The portal the screen asked to open the order through.
  String? requestedGateway;

  @override
  Future<PaymentOrder> createOrder(
    String roomId, {
    String gateway = kDefaultGateway,
  }) async {
    requestedGateway = gateway;
    final momo = gateway == 'MOMO';
    return PaymentOrder(
      txnRef: '20261109ABCD',
      payUrl: momo
          ? 'https://test-payment.momo.vn/v2/gateway/pay?orderId=20261109ABCD'
          : 'http://10.0.2.2:3300/api/payment/dev/checkout/20261109ABCD',
      amount: 1400000,
      status: 'PENDING',
      orderInfo: 'Dat coc tro tot 20261109ABCD',
      gateway: gateway,
      deeplink: momo ? 'momo://payment?token=abc' : null,
      qrCodeUrl: momo ? 'https://momo.vn/qr/abc.png' : null,
    );
  }

  @override
  Future<PaymentResult> status(String txnRef) async =>
      result ??
      PaymentResult(
        status: 'PENDING',
        txnRef: '20261109ABCD',
        amount: 1400000,
        bankName: requestedGateway == 'MOMO' ? 'MOMO' : 'VNPAY',
        gateway: requestedGateway ?? kDefaultGateway,
        transactionNo: null,
        responseCode: null,
        payDate: null,
        message: 'Giao dịch chưa hoàn tất',
      );

  @override
  Future<PaymentResult> cancel(String txnRef) async => const PaymentResult(
    status: 'CANCELLED',
    txnRef: '20261109ABCD',
    amount: 1400000,
    bankName: 'VNPAY',
    transactionNo: null,
    responseCode: '24',
    payDate: null,
    message: 'Giao dịch không thành công do: Khách hàng hủy giao dịch',
  );

  @override
  Future<List<RoomDeposit>> deposits() async => throw UnimplementedError();
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

Future<void> _pump(
  WidgetTester tester,
  PaymentApi api, {
  String? txnRef,
}) async {
  // A phone-width surface: the demo card overflows at the 800x600 test size.
  // Tall enough that the whole payment page lays out at once, so nothing in
  // the list can be disposed off-screen between taps and assertions.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1080, 7200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: ThemeData.light(),
        home: txnRef == null
            ? PaymentScreen(room: _room)
            : PaymentScreen(txnRef: txnRef),
      ),
    ),
  );
}

String _brand(String gateway) => gateway == 'MOMO' ? 'MoMo' : 'VNPay';

/// Opens a checkout the way a student does: choose a portal, then ask for the
/// order. Nothing exists on the server until that button is pressed.
Future<void> _checkout(
  WidgetTester tester,
  _FakePaymentApi api, {
  String gateway = 'VNPAY',
}) async {
  await _pump(tester, api);
  await tester.pumpAndSettle();
  if (gateway != 'VNPAY') await _tap(tester, find.text(_brand(gateway)));
  await _tap(
    tester,
    find.widgetWithText(FilledButton, 'Thanh toán qua ${_brand(gateway)}'),
  );
}

// A tap needs the target in the viewport, so bring it into view first.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Records the urls the screen asks the platform to open. Links listed in
/// [fail] come back un-openable, the way a device without MoMo behaves.
List<String> _recordLaunches(
  WidgetTester tester, {
  Set<String> fail = const {},
}) {
  final launched = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        // The plugin still routes launchUrl through the legacy 'launch'
        // method on the method-channel implementation.
        if (call.method != 'launch' && call.method != 'launchUrl') return true;
        final url = (call.arguments as Map<Object?, Object?>?)?['url'];
        if (url is! String) return true;
        launched.add(url);
        return !fail.contains(url);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return launched;
}

void main() {
  testWidgets('asks which portal to pay through before ordering', (
    tester,
  ) async {
    final api = _FakePaymentApi();
    await _pump(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Chọn cổng thanh toán'), findsOne);
    expect(find.text('VNPay'), findsOne);
    expect(find.text('MoMo'), findsOne);
    expect(find.text('Thanh toán qua VNPay'), findsOne);
    expect(find.text('Thông tin thanh toán'), findsNothing);
    expect(api.requestedGateway, isNull);
  });

  testWidgets('shows the portal checkout card before paying', (tester) async {
    final api = _FakePaymentApi();
    await _checkout(tester, api);

    expect(api.requestedGateway, 'VNPAY');
    expect(find.text('VNPAY'), findsOne);
    expect(find.text('SANDBOX'), findsOne);
    expect(find.text('Thông tin thanh toán'), findsOne);
    expect(find.text('1.400.000 VND'), findsOne);
    expect(find.text('Dat coc tro tot 20261109ABCD'), findsOne);
    expect(find.text('Cổng thanh toán VNPay'), findsOne);
    expect(find.text('Thanh toán ngay'), findsOne);
    expect(find.byIcon(Icons.qr_code), findsNothing);
  });

  testWidgets('opens a MoMo order when MoMo is the choice', (tester) async {
    final api = _FakePaymentApi();
    await _checkout(tester, api, gateway: 'MOMO');

    expect(api.requestedGateway, 'MOMO');
    expect(find.text('MOMO'), findsOne);
    expect(find.text('SANDBOX'), findsOne);
    expect(find.text('Cổng thanh toán MoMo'), findsOne);
    expect(find.text('Giao dịch của bạn được bảo vệ bởi MoMo.'), findsOne);
    expect(find.textContaining('HMAC-SHA256'), findsOne);
  });

  testWidgets('switches portal before paying the first checkout', (
    tester,
  ) async {
    final api = _FakePaymentApi();
    await _checkout(tester, api);

    await _tap(tester, find.text('Đổi cổng thanh toán'));
    expect(find.text('Chọn cổng thanh toán'), findsOne);

    await _tap(tester, find.text('MoMo'));
    await _tap(
      tester,
      find.widgetWithText(FilledButton, 'Thanh toán qua MoMo'),
    );

    expect(api.requestedGateway, 'MOMO');
    expect(find.text('MOMO'), findsOne);
  });

  testWidgets('renders the VNPay result once the order is paid', (
    tester,
  ) async {
    await _checkout(
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
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Trạng thái giao dịch'), findsOne);
    expect(find.text('Giao dịch thành công'), findsOne);
    expect(find.text('Mã 00'), findsOne);
    expect(find.text('12345'), findsOne);
    expect(find.text('09/11/2026 10:27:08'), findsOne);
    expect(find.text('Thanh toán ngay'), findsNothing);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('labels a paid MoMo transaction as MoMo', (tester) async {
    await _checkout(
      tester,
      _FakePaymentApi(
        result: const PaymentResult(
          status: 'PAID',
          txnRef: '20261109ABCD',
          amount: 1400000,
          bankName: 'MOMO',
          gateway: 'MOMO',
          transactionNo: '9042738472',
          responseCode: '00',
          payDate: '20261109102708',
          message: 'Giao dịch thành công',
        ),
      ),
      gateway: 'MOMO',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Mã giao dịch MoMo'), findsOne);
    expect(find.text('9042738472'), findsOne);
  });

  testWidgets('cancels the deposit after the confirm dialog', (tester) async {
    await _checkout(tester, _FakePaymentApi());

    await _tap(tester, find.widgetWithText(OutlinedButton, 'Hủy cọc'));
    expect(find.text('Hủy đặt cọc?'), findsOne);

    await tester.tap(find.widgetWithText(FilledButton, 'Hủy cọc'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();

    expect(find.text('Trạng thái giao dịch'), findsOne);
    expect(find.text('Mã 24'), findsOne);
    expect(find.text('Hủy cọc'), findsNothing);
    expect(find.text('Thanh toán ngay'), findsNothing);
  });

  testWidgets('re-reads the order when the portal hands the app back', (
    tester,
  ) async {
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
      txnRef: '20261109ABCD',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mã tham chiếu'), findsOne);
    expect(find.text('Trạng thái giao dịch'), findsOne);
    expect(find.text('Giao dịch thành công'), findsOne);
    expect(find.text('Mã 00'), findsOne);
    expect(find.text('Thanh toán ngay'), findsNothing);
    expect(find.text('Phòng trọ Minh Thạnh'), findsNothing);
    // Hai dấu check = đang ở bước "Kết quả". Màn này không có đơn cục bộ nên
    // trước đây thanh tiến trình tụt về bước "Chọn cổng".
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('keeps the progress bar on paying while the portal is pending', (
    tester,
  ) async {
    await _pump(tester, _FakePaymentApi(), txnRef: '20261109ABCD');
    await tester.pumpAndSettle();

    expect(find.text('Đang xử lý'), findsOne);
    expect(find.byIcon(Icons.check), findsNWidgets(1));
  });

  testWidgets('opens the MoMo wallet before the web page', (tester) async {
    final launched = _recordLaunches(tester);
    await _checkout(tester, _FakePaymentApi(), gateway: 'MOMO');
    await _tap(tester, find.widgetWithText(FilledButton, 'Thanh toán ngay'));

    expect(launched, ['momo://payment?token=abc']);
  });

  testWidgets('falls back to the web when the wallet app is missing', (
    tester,
  ) async {
    final launched = _recordLaunches(
      tester,
      fail: {'momo://payment?token=abc'},
    );
    await _checkout(tester, _FakePaymentApi(), gateway: 'MOMO');
    await _tap(tester, find.widgetWithText(FilledButton, 'Thanh toán ngay'));

    expect(launched, [
      'momo://payment?token=abc',
      'https://test-payment.momo.vn/v2/gateway/pay?orderId=20261109ABCD',
    ]);
  });

  testWidgets('VNPay has no wallet link, so it opens the page directly', (
    tester,
  ) async {
    final launched = _recordLaunches(tester);
    await _checkout(tester, _FakePaymentApi());
    await _tap(tester, find.widgetWithText(FilledButton, 'Thanh toán ngay'));

    expect(launched, [
      'http://10.0.2.2:3300/api/payment/dev/checkout/20261109ABCD',
    ]);
  });

  testWidgets('shows the MoMo QR and its result codes', (tester) async {
    await _checkout(tester, _FakePaymentApi(), gateway: 'MOMO');

    expect(find.text('Quét mã bằng ứng dụng MoMo để thanh toán'), findsOne);

    await _tap(tester, find.text('Xem mã kết quả MoMo'));
    expect(find.text('Mã kết quả MoMo'), findsOne);
    expect(find.text('7000'), findsOne);
    expect(find.text('Giao dịch đang được xử lý.'), findsOne);
  });

  testWidgets('names the pending state and logs what the portal answered', (
    tester,
  ) async {
    await _checkout(tester, _FakePaymentApi(), gateway: 'MOMO');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Đang xử lý'), findsOne);
    expect(find.text('Nhật ký cổng thanh toán'), findsOne);
    expect(find.textContaining('MOMO: 1400000 VND, có deep link ví'), findsOne);
    expect(find.textContaining('PENDING: chưa có mã'), findsOne);
  });

  testWidgets('names a refused MoMo payment as a failure', (tester) async {
    await _checkout(
      tester,
      _FakePaymentApi(
        result: const PaymentResult(
          status: 'FAILED',
          txnRef: '20261109ABCD',
          amount: 1400000,
          bankName: 'MOMO',
          gateway: 'MOMO',
          transactionNo: null,
          responseCode: '1001',
          payDate: null,
          message: 'Giao dịch thất bại do không đủ tiền.',
        ),
      ),
      gateway: 'MOMO',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Thất bại'), findsOne);
    expect(find.text('Mã 1001'), findsOne);
    expect(find.text('Đang xử lý'), findsNothing);
  });
}
