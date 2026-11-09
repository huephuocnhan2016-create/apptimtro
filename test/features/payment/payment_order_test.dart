import 'package:flutter_test/flutter_test.dart';
import 'package:apptimtro/features/payment/domain/payment_order.dart';

void main() {
  test('parses a payment order with its portal url', () {
    final order = PaymentOrder.fromJson({
      'txnRef': '20261109ABCD',
      'payUrl': 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?txn=1',
      'amount': 3000000,
      'status': 'PENDING',
      'orderInfo': 'Dat coc tro tot 20261109ABCD',
    });

    expect(order.payUrl, contains('vnpayment.vn'));
    expect(order.orderInfo, 'Dat coc tro tot 20261109ABCD');
    expect(order.status, 'PENDING');
  });

  test('rejects an order response without a portal url', () {
    expect(
      () => PaymentOrder.fromJson({
        'txnRef': '20261109ABCD',
        'amount': 3000000,
        'status': 'PENDING',
        'orderInfo': 'Dat coc',
      }),
      throwsFormatException,
    );
  });

  test('parses a settled result and exposes its transaction details', () {
    final result = PaymentResult.fromJson({
      'status': 'PAID',
      'txnRef': '20261109ABCD',
      'amount': 3000000,
      'bankName': 'VNPAY',
      'transactionNo': '12345',
      'responseCode': '00',
      'payDate': '20261109102708',
      'message': 'Giao dịch thành công',
    });

    expect(result.isSettled, isTrue);
    expect(result.payDate, '20261109102708');
    expect(result.message, 'Giao dịch thành công');
  });

  test('keeps the wallet links that come with a MoMo order', () {
    final momo = PaymentOrder.fromJson({
      'txnRef': '20261109ABCD',
      'payUrl': 'https://test-payment.momo.vn/v2/gateway/pay',
      'amount': 3000000,
      'status': 'PENDING',
      'orderInfo': 'Dat coc tro tot 20261109ABCD',
      'gateway': 'MOMO',
      'deeplink': 'momo://payment?token=abc',
      'qrCodeUrl': 'https://momo.vn/qr/abc.png',
    });

    expect(momo.deeplink, 'momo://payment?token=abc');
    expect(momo.qrCodeUrl, 'https://momo.vn/qr/abc.png');

    final webOnly = PaymentOrder.fromJson({
      'txnRef': '20261109ABCD',
      'payUrl': 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
      'amount': 3000000,
      'status': 'PENDING',
      'orderInfo': 'Dat coc tro tot 20261109ABCD',
      'deeplink': '',
      'qrCodeUrl': null,
    });

    expect(webOnly.deeplink, isNull);
    expect(webOnly.qrCodeUrl, isNull);
  });

  test('a pending result keeps polling', () {
    final result = PaymentResult.fromJson({
      'status': 'PENDING',
      'txnRef': '20261109ABCD',
      'amount': 3000000,
      'bankName': 'VNPAY',
      'transactionNo': null,
      'responseCode': null,
      'payDate': null,
      'message': 'Giao dịch chưa hoàn tất',
    });

    expect(result.isSettled, isFalse);
    expect(result.transactionNo, isNull);
  });

  test('reads which portal the order was opened through', () {
    final momo = PaymentOrder.fromJson({
      'txnRef': '20261109ABCD',
      'payUrl': 'https://payment.momo.vn/v2/gateway/pay?id=1',
      'amount': 3000000,
      'status': 'PENDING',
      'orderInfo': 'Dat coc tro tot 20261109ABCD',
      'gateway': 'MOMO',
    });
    // An older order pre-dates the gateway column and still has to render.
    final legacy = PaymentOrder.fromJson({
      'txnRef': '20261109EFGH',
      'payUrl': 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?txn=2',
      'amount': 3000000,
      'status': 'PENDING',
      'orderInfo': 'Dat coc tro tot 20261109EFGH',
    });

    expect(momo.gateway, 'MOMO');
    expect(legacy.gateway, 'VNPAY');
    expect(
      PaymentResult.fromJson(const {
        'status': 'PAID',
        'txnRef': '20261109ABCD',
        'amount': 3000000,
        'bankName': 'MOMO',
        'gateway': 'MOMO',
        'transactionNo': '9042738472',
        'responseCode': '00',
        'payDate': '20261109102708',
        'message': 'Giao dịch thành công',
      }).gateway,
      'MOMO',
    );
  });
}
