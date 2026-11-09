import '../../../core/network/api_client.dart';
import '../domain/payment_order.dart';

class PaymentApi {
  PaymentApi(this._client);

  final ApiClient _client;

  Future<PaymentOrder> createOrder(String roomId) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/payment/orders',
      data: {'roomId': roomId},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Invalid payment order response.');
    }
    return PaymentOrder.fromJson(data);
  }

  Future<PaymentResult> status(String txnRef) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/payment/orders/$txnRef/status',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Invalid payment status response.');
    }
    return PaymentResult.fromJson(data);
  }

  Future<PaymentResult> cancel(String txnRef) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/payment/orders/$txnRef/cancel',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Invalid payment cancel response.');
    }
    return PaymentResult.fromJson(data);
  }

  Future<List<RoomDeposit>> deposits() async {
    final response = await _client.dio.get<List<dynamic>>(
      '/payment/deposits',
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoomDeposit.fromJson)
        .toList();
  }
}
