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
}
