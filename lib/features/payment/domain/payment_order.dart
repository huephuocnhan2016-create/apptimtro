class PaymentOrder {
  const PaymentOrder({
    required this.txnRef,
    required this.qrcontent,
    required this.amount,
    required this.status,
  });

  final String txnRef;
  final String qrcontent;
  final num amount;
  final String status;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final txnRef = json['txnRef'];
    final qrcontent = json['qrcontent'];
    final amount = json['amount'];
    final status = json['status'];
    if (txnRef is! String ||
        qrcontent is! String ||
        amount is! num ||
        status is! String) {
      throw const FormatException('Invalid payment order response.');
    }
    return PaymentOrder(
      txnRef: txnRef,
      qrcontent: qrcontent,
      amount: amount,
      status: status,
    );
  }

  PaymentOrder withStatus(String value) => PaymentOrder(
    txnRef: txnRef,
    qrcontent: qrcontent,
    amount: amount,
    status: value,
  );
}
