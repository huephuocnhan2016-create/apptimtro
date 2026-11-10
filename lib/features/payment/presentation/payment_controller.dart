import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../domain/payment_order.dart';

/// Màn thanh toán mở theo một trong hai cách: từ phòng (tạo đơn mới) hoặc từ
/// link "Về ứng dụng" của cổng (chỉ có txnRef để đọc lại đơn).
typedef PaymentArgs = ({String? roomId, String? txnRef});

/// "MOMO" → "MoMo", còn lại → "VNPay" (tên cổng như người dùng đọc).
String portalDisplayName(String gateway) =>
    gateway == 'MOMO' ? 'MoMo' : 'VNPay';

@immutable
class PaymentState {
  const PaymentState({
    this.txnRefFromLink,
    this.order,
    this.result,
    this.error,
    this.loading = false,
    this.launching = false,
    this.cancelling = false,
    this.gateway = kDefaultGateway,
    this.debugLog = const [],
  });

  /// txnRef nhận từ deep link (khi không có đơn cục bộ).
  final String? txnRefFromLink;
  final PaymentOrder? order;
  final PaymentResult? result;
  final String? error;
  final bool loading;
  final bool launching;
  final bool cancelling;

  /// Cổng người dùng chọn. Chỉ dùng để mở đơn; có đơn rồi thì cổng do server
  /// ghi trên đơn mới là cổng hiển thị.
  final String gateway;

  /// Nhật ký demo: app đã nhờ cổng làm gì, cổng trả lời gì. Chỉ ghi ở bản
  /// debug, không bao giờ chứa bí mật hay token.
  final List<String> debugLog;

  String get activeGateway => result?.gateway ?? order?.gateway ?? gateway;
  bool get isMomo => activeGateway == 'MOMO';
  String? get activeTxnRef => order?.txnRef ?? txnRefFromLink;
  bool get isSettled => result?.isSettled ?? false;

  bool get canCancel {
    if (activeTxnRef == null) return false;
    final status = result?.status;
    return status == null || status == 'PENDING' || status == 'PAID';
  }

  static const _unset = Object();

  PaymentState copyWith({
    Object? order = _unset,
    Object? result = _unset,
    Object? error = _unset,
    bool? loading,
    bool? launching,
    bool? cancelling,
    String? gateway,
    List<String>? debugLog,
  }) => PaymentState(
    txnRefFromLink: txnRefFromLink,
    order: identical(order, _unset) ? this.order : order as PaymentOrder?,
    result: identical(result, _unset) ? this.result : result as PaymentResult?,
    error: identical(error, _unset) ? this.error : error as String?,
    loading: loading ?? this.loading,
    launching: launching ?? this.launching,
    cancelling: cancelling ?? this.cancelling,
    gateway: gateway ?? this.gateway,
    debugLog: debugLog ?? this.debugLog,
  );
}

final paymentControllerProvider = NotifierProvider.autoDispose
    .family<PaymentController, PaymentState, PaymentArgs>(
      PaymentController.new,
    );

class PaymentController extends Notifier<PaymentState> {
  PaymentController(this.args);

  final PaymentArgs args;

  Timer? _timer;
  bool _checkingStatus = false;

  @override
  PaymentState build() {
    ref.onDispose(() => _timer?.cancel());
    final txnRef = args.txnRef;
    if (txnRef != null) {
      // Không được đổi state ngay trong build → chạy ngay sau đó.
      Future.microtask(_readExistingOrder);
    }
    return PaymentState(txnRefFromLink: txnRef, loading: txnRef != null);
  }

  void selectGateway(String gateway) =>
      state = state.copyWith(gateway: gateway);

  void _log(String line) {
    if (!kDebugMode || !ref.mounted) return;
    final log = [line, ...state.debugLog];
    state = state.copyWith(debugLog: log.length > 6 ? log.sublist(0, 6) : log);
  }

  Future<void> createOrder() async {
    final roomId = args.roomId;
    if (roomId == null) return;
    _timer?.cancel();
    state = state.copyWith(
      loading: true,
      error: null,
      order: null,
      result: null,
    );
    try {
      final order = await ref
          .read(paymentApiProvider)
          .createOrder(roomId, gateway: state.gateway);
      if (!ref.mounted) return;
      state = state.copyWith(order: order, loading: false);
      _log(
        '${order.gateway}: ${order.amount.toInt()} VND, '
        '${order.deeplink != null ? 'có deep link ví' : 'chỉ link web'}',
      );
      if (order.status == 'PENDING') _startPolling();
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Không tạo được yêu cầu đặt cọc: ${apiErrorMessage(error)}',
      );
    }
  }

  /// Đổi cổng chỉ xóa đơn cục bộ: máy chủ tự hủy đơn PENDING của cổng cũ khi
  /// tạo đơn mới, nên mỗi phòng luôn chỉ còn một yêu cầu cọc đang hiệu lực.
  void chooseAnotherGateway() {
    _timer?.cancel();
    state = state.copyWith(
      order: null,
      result: null,
      error: null,
      loading: false,
    );
  }

  /// Quay về từ cổng thì không có đơn cục bộ, chỉ có txnRef trong link → dựng
  /// lại màn hình từ dữ liệu server.
  Future<void> _readExistingOrder() async {
    final txnRef = args.txnRef;
    if (txnRef == null || !ref.mounted) return;
    _timer?.cancel();
    state = state.copyWith(loading: true, error: null, result: null);
    try {
      final result = await ref.read(paymentApiProvider).status(txnRef);
      if (!ref.mounted) return;
      state = state.copyWith(result: result, loading: false);
      if (!result.isSettled) _startPolling();
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Không đọc được đặt cọc: ${apiErrorMessage(error)}',
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => checkStatus());
  }

  Future<void> openPortal() async {
    final order = state.order;
    if (order == null || state.launching) return;
    state = state.copyWith(launching: true);
    final portalName = portalDisplayName(state.activeGateway);
    // Demo mở MoMo trong app ví trước, không được mới quay về trang web, vì
    // không phải máy test nào cũng cài MoMo.
    final links = <(String, String)>[
      if (state.isMomo && order.deeplink != null)
        ('app $portalName', order.deeplink!),
      ('trang web', order.payUrl),
    ];
    var opened = false;
    for (final link in links) {
      opened = await _launch(link.$2);
      _log('Mở ${link.$1}: ${opened ? 'thành công' : 'không được'}');
      if (opened) break;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      launching: false,
      error: opened
          ? state.error
          : 'Không mở được cổng thanh toán $portalName.',
    );
  }

  /// Lỗi khi mở link → trả `false` để thử link kế tiếp (web).
  Future<bool> _launch(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        // Chrome custom tab chặn intent:// sang app khác, nên nút "Về ứng dụng"
        // của cổng chỉ hoạt động khi mở bằng trình duyệt thật.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Gọi mỗi 3 giây khi đang chờ, và mỗi khi app quay lại từ trình duyệt.
  Future<void> checkStatus() async {
    final txnRef = state.activeTxnRef;
    if (txnRef == null || _checkingStatus || state.isSettled) return;
    _checkingStatus = true;
    try {
      final result = await ref.read(paymentApiProvider).status(txnRef);
      if (!ref.mounted) return;
      state = state.copyWith(result: result, error: null);
      _log(
        '${result.status}: ${result.responseCode == null ? 'chưa có mã' : 'mã ${result.responseCode}'}'
        ' — ${result.message}',
      );
      if (result.isSettled) _timer?.cancel();
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: 'Không kiểm tra được trạng thái: ${apiErrorMessage(error)}',
      );
    } finally {
      _checkingStatus = false;
    }
  }

  /// Hủy cọc (màn hình đã hỏi xác nhận trước khi gọi).
  Future<void> cancel() async {
    final txnRef = state.activeTxnRef;
    if (txnRef == null || state.cancelling) return;
    state = state.copyWith(cancelling: true);
    try {
      final result = await ref.read(paymentApiProvider).cancel(txnRef);
      if (!ref.mounted) return;
      _timer?.cancel();
      state = state.copyWith(result: result, error: null, cancelling: false);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        cancelling: false,
        error: 'Không hủy được đặt cọc: ${apiErrorMessage(error)}',
      );
    }
  }
}
