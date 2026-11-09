/// Which checkout portal an order was opened through. The backend stores the
/// same strings in its PaymentGateway enum and answers every payment route with
/// them, so the app never has to guess a portal from a URL.
const String kDefaultGateway = 'VNPAY';

class PaymentOrder {
  const PaymentOrder({
    required this.txnRef,
    required this.payUrl,
    required this.amount,
    required this.status,
    required this.orderInfo,
    this.gateway = kDefaultGateway,
    this.deeplink,
    this.qrCodeUrl,
  });

  final String txnRef;
  final String payUrl;
  final num amount;
  final String status;
  final String orderInfo;
  final String gateway;

  /// MoMo answers with a wallet deep link and a QR image next to the web page;
  /// portals that only have a web checkout leave both null.
  final String? deeplink;
  final String? qrCodeUrl;

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
      gateway: gatewayFromJson(json['gateway']),
      deeplink: optionalLink(json['deeplink']),
      qrCodeUrl: optionalLink(json['qrCodeUrl']),
    );
  }
}

String? optionalLink(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String gatewayFromJson(Object? value) =>
    value is String && value.isNotEmpty ? value : kDefaultGateway;

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
    this.gateway = kDefaultGateway,
  });

  final String status;
  final String txnRef;
  final num amount;
  final String bankName;
  final String gateway;
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
      gateway: gatewayFromJson(json['gateway']),
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
    gateway: gateway,
    transactionNo: transactionNo,
    responseCode: responseCode,
    payDate: payDate,
    message: message,
  );
}

/// A deposit the student is holding, with just enough of the room to show it
/// in the profile list and open its detail page.
class RoomDeposit {
  const RoomDeposit({
    required this.txnRef,
    required this.amount,
    required this.payDate,
    required this.roomId,
    required this.roomTitle,
    required this.roomAddress,
    this.roomImage,
  });

  final String txnRef;
  final num amount;
  final DateTime? payDate;
  final String roomId;
  final String roomTitle;
  final String roomAddress;
  final String? roomImage;

  factory RoomDeposit.fromJson(Map<String, dynamic> json) {
    final txnRef = json['txnRef'];
    final amount = json['amount'];
    final room = json['room'];
    if (txnRef is! String || amount is! num || room is! Map<String, dynamic>) {
      throw const FormatException('Invalid deposit list response.');
    }
    final roomId = room['id'];
    final title = room['title'];
    final address = room['address'];
    if (roomId is! String || title is! String || address is! String) {
      throw const FormatException('Invalid deposit room response.');
    }
    return RoomDeposit(
      txnRef: txnRef,
      amount: amount,
      payDate: DateTime.tryParse(json['payDate'] as String? ?? ''),
      roomId: roomId,
      roomTitle: title,
      roomAddress: address,
      roomImage: room['image'] as String?,
    );
  }
}
