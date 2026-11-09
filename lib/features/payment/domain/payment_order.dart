class PaymentOrder {
  const PaymentOrder({
    required this.txnRef,
    required this.payUrl,
    required this.amount,
    required this.status,
    required this.orderInfo,
  });

  final String txnRef;
  final String payUrl;
  final num amount;
  final String status;
  final String orderInfo;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final txnRef = json['txnRef'];
    final payUrl = json['payUrl'];
    final amount = json['amount'];
    final status = json['status'];
    final orderInfo = json['orderInfo'];
    if (txnRef is! String ||
        payUrl is! String ||
        amount is! num ||
        status is! String ||
        orderInfo is! String) {
      throw const FormatException('Invalid payment order response.');
    }
    return PaymentOrder(
      txnRef: txnRef,
      payUrl: payUrl,
      amount: amount,
      status: status,
      orderInfo: orderInfo,
    );
  }
}

class PaymentResult {
  const PaymentResult({
    required this.status,
    required this.txnRef,
    required this.amount,
    required this.bankName,
    required this.transactionNo,
    required this.responseCode,
    required this.payDate,
    required this.message,
  });

  final String status;
  final String txnRef;
  final num amount;
  final String bankName;
  final String? transactionNo;
  final String? responseCode;
  final String? payDate;
  final String message;

  bool get isSettled => status != 'PENDING';

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final txnRef = json['txnRef'];
    final amount = json['amount'];
    final bankName = json['bankName'];
    final message = json['message'];
    if (status is! String ||
        txnRef is! String ||
        amount is! num ||
        bankName is! String ||
        message is! String) {
      throw const FormatException('Invalid payment status response.');
    }
    return PaymentResult(
      status: status,
      txnRef: txnRef,
      amount: amount,
      bankName: bankName,
      transactionNo: json['transactionNo'] as String?,
      responseCode: json['responseCode'] as String?,
      payDate: json['payDate'] as String?,
      message: message,
    );
  }

  PaymentResult copyWithStatus(String value) => PaymentResult(
    status: value,
    txnRef: txnRef,
    amount: amount,
    bankName: bankName,
    transactionNo: transactionNo,
    responseCode: responseCode,
    payDate: payDate,
    message: message,
  );
}
