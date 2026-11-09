import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../rooms/domain/room.dart';
import '../domain/momo_result_codes.dart';
import '../domain/payment_order.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({this.room, this.txnRef, super.key})
    : assert(room != null || txnRef != null);

  final Room? room;

  /// Set instead of [room] when the payment portal hands the app back a
  /// transaction to re-read, because the browser link carries no room.
  final String? txnRef;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  PaymentOrder? _order;
  PaymentResult? _result;
  Timer? _timer;
  String? _error;
  bool _loading = false;
  bool _checkingStatus = false;
  bool _launching = false;
  bool _cancelling = false;

  /// The portal the student picked. Only used to open an order; once there is
  /// one, the server's own gateway column is what the screen shows.
  String _gateway = kDefaultGateway;

  /// The demo's debug switch: what the app asked the portal to do and what it
  /// answered. Only collected in debug builds, and never a secret or a token.
  final List<String> _debugLog = [];

  void _log(String line) {
    if (!kDebugMode || !mounted) return;
    setState(() {
      _debugLog.insert(0, line);
      if (_debugLog.length > 6) _debugLog.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.txnRef != null) {
      _readExistingOrder();
    }
  }

  bool get _isMomo => _activeGateway == 'MOMO';

  String get _activeGateway =>
      _result?.gateway ?? _order?.gateway ?? _gateway;

  /// Upper-case, as the portals write their own names on the checkout page.
  String get _portalLabel => _isMomo ? 'MOMO' : 'VNPAY';

  /// Brand-cased, for the choices the student reads.
  String get _portalName => _portalDisplayName(_activeGateway);

  static String _portalDisplayName(String gateway) =>
      gateway == 'MOMO' ? 'MoMo' : 'VNPay';

  Color get _portalBrand => _isMomo ? AppColors.momo : AppColors.brand;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The portal opens in a browser tab, so coming back is the real "I'm done"
    // signal the app can act on without a deep link handler.
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _createOrder() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _order = null;
      _result = null;
    });
    try {
      final order = await ref
          .read(paymentApiProvider)
          .createOrder(widget.room!.id, gateway: _gateway);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
      _log(
        '${order.gateway}: ${order.amount.toInt()} VND, '
        '${order.deeplink != null ? 'có deep link ví' : 'chỉ link web'}',
      );
      if (order.status == 'PENDING') _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tạo được yêu cầu đặt cọc: ${apiErrorMessage(error)}';
      });
    }
  }

  // Switching portals means dropping the checkout that was never paid for, so
  // the student is not left holding an order under the old gateway.
  void _chooseAnotherGateway() {
    _timer?.cancel();
    setState(() {
      _order = null;
      _result = null;
      _error = null;
      _loading = false;
    });
  }

  String? get _activeTxnRef => _order?.txnRef ?? widget.txnRef;

  // Coming back from the portal there is no local order, only the reference the
  // link carried, so the screen is rebuilt from the server's view of it.
  Future<void> _readExistingOrder() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(paymentApiProvider)
          .status(widget.txnRef!);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
      if (!result.isSettled) _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không đọc được đặt cọc: ${apiErrorMessage(error)}';
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  Future<void> _openPortal() async {
    final order = _order;
    if (order == null || _launching) return;
    setState(() => _launching = true);
    // The demo opens MoMo inside the wallet app and only falls back to the web
    // page, because no test device is guaranteed to have MoMo installed.
    final links = <(String, String)>[
      if (_isMomo && order.deeplink != null) (
        'app $_portalName',
        order.deeplink!,
      ),
      ('trang web', order.payUrl),
    ];
    var opened = false;
    for (final link in links) {
      opened = await _launch(link.$2);
      _log('Mở ${link.$1}: ${opened ? 'thành công' : 'không được'}');
      if (opened) break;
    }
    if (!mounted) return;
    setState(() {
      _launching = false;
      if (!opened) _error = 'Không mở được cổng thanh toán $_portalName.';
    });
  }

  Future<bool> _launch(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        // A Chrome custom tab refuses intent:// links to another package, so
        // the portal's "Về ứng dụng" button only lands in a real browser tab.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkStatus() async {
    final txnRef = _activeTxnRef;
    if (txnRef == null || _checkingStatus) return;
    if (_result?.isSettled ?? false) return;
    _checkingStatus = true;
    try {
      final result = await ref.read(paymentApiProvider).status(txnRef);
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
      });
      _log(
        '${result.status}: ${result.responseCode == null ? 'chưa có mã' : 'mã ${result.responseCode}'}'
        ' — ${result.message}',
      );
      if (result.isSettled) _timer?.cancel();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không kiểm tra được trạng thái: ${apiErrorMessage(error)}';
      });
    } finally {
      _checkingStatus = false;
    }
  }

  bool get _canCancel {
    if (_activeTxnRef == null) return false;
    final status = _result?.status;
    return status == null || status == 'PENDING' || status == 'PAID';
  }

  Future<void> _cancelDeposit() async {
    final txnRef = _activeTxnRef;
    if (txnRef == null || _cancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đặt cọc?'),
        content: const Text(
          'Phòng sẽ được mở lại cho người khác đặt cọc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ cọc'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy cọc'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final result = await ref.read(paymentApiProvider).cancel(txnRef);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _result = result;
        _error = null;
        _cancelling = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = 'Không hủy được đặt cọc: ${apiErrorMessage(error)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceAlt,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _brandHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroCard(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_order == null && widget.txnRef == null)
                  _error != null ? _errorCard() : _gatewayPicker()
                else ...[
                  if (_order != null) _infoCard(_order!) else _referenceCard(),
                  const SizedBox(height: 16),
                  if (_order != null && (_result == null || !_result!.isSettled))
                    ...[_payButton(), _gatewaySwitch()],
                  if (_canCancel) ...[
                    const SizedBox(height: 12),
                    _cancelButton(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.failure, fontSize: 13),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _resultCard(_result!),
                  ],
                  if (_result == null || !_result!.isSettled) ...[
                    const SizedBox(height: 16),
                    _pendingNote(),
                  ],
                  if (_debugLog.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _debugCard(),
                  ],
                ],
                const SizedBox(height: 20),
                _serverSignedNote(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _brandHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
    child: Row(
      children: [
        IconButton(
          // The portal hands the app a deep link, which starts this screen as
          // the only route, so there is usually nothing underneath to pop.
          onPressed: () async {
            if (!mounted) return;
            if (!await Navigator.of(context).maybePop()) {
              if (mounted) context.go('/splash');
            }
          },
          icon: const Icon(Icons.chevron_left, color: AppColors.ink),
        ),
        _BrandMark(
          label: _isMomo ? 'M' : 'VN',
          brand: _portalBrand,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _portalLabel,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.1,
                ),
              ),
              const Text(
                'THANH TOÁN AN TOÀN',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (_isSandbox)
          const _Pill(
            label: 'SANDBOX',
            background: AppColors.warningSoft,
            foreground: AppColors.warningInk,
          ),
      ],
    ),
  );

  bool get _isSandbox {
    final order = _order;
    if (order == null) return false;
    // Both the shared dev checkout page and MoMo's test host stand in for a
    // portal that no real money moves through.
    return order.payUrl.contains('sandbox') ||
        order.payUrl.contains('/dev/') ||
        order.payUrl.contains('test-payment.momo.vn');
  }

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isMomo
            ? const [AppColors.momo, AppColors.momoDark]
            : const [AppColors.brand, AppColors.brandDark],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill(
          label: 'CÔNG THANH TOÁN TRỰC TUYẾN',
          background: AppColors.onBrandOverlay,
          foreground: Colors.white,
        ),
        const SizedBox(height: 14),
        const Text(
          'Thanh toán nhanh chóng,\nan tâm tuyệt đối.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Giao dịch của bạn được bảo vệ bởi $_portalName.',
          style: const TextStyle(color: AppColors.onBrandMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HeroBadge(icon: Icons.lock_outline, label: 'Bảo mật'),
            _HeroBadge(
              icon: Icons.verified_user_outlined,
              label: 'Xác thực giao dịch',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _errorCard() => _Card(
    title: 'Không tạo được yêu cầu đặt cọc',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.failure, fontSize: 13)),
        const SizedBox(height: 14),
        FilledButton(onPressed: _createOrder, child: const Text('Thử lại')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _chooseAnotherGateway,
          child: const Text('Chọn cổng khác'),
        ),
      ],
    ),
  );

  Widget _gatewayPicker() => _Card(
    title: 'Chọn cổng thanh toán',
    subtitle: 'App tạo yêu cầu sau khi bạn chọn, chưa trừ tiền ở bước này',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GatewayOption(
          value: 'VNPAY',
          selected: _gateway == 'VNPAY',
          brand: AppColors.brand,
          mark: 'VN',
          name: 'VNPay',
          detail: 'Chuyển khoản ngân hàng, ví VNPay, thẻ nội địa',
          onSelect: (value) => setState(() => _gateway = value),
        ),
        const SizedBox(height: 10),
        _GatewayOption(
          value: 'MOMO',
          selected: _gateway == 'MOMO',
          brand: AppColors.momo,
          mark: 'M',
          name: 'MoMo',
          detail: 'Ví MoMo, QR MoMo, thẻ quốc tế',
          onSelect: (value) => setState(() => _gateway = value),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _createOrder,
          style: FilledButton.styleFrom(
            backgroundColor: _portalBrand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.arrow_forward),
          label: Text('Thanh toán qua $_portalName'),
        ),
      ],
    ),
  );

  Widget _gatewaySwitch() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextButton.icon(
      onPressed: _chooseAnotherGateway,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: const Text('Đổi cổng thanh toán'),
    ),
  );

  Widget _infoCard(PaymentOrder order) => _Card(
    title: 'Thông tin thanh toán',
    subtitle: 'Kiểm tra thông tin trước khi tiếp tục',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'Số tiền thanh toán',
          value:
              '${NumberFormat.decimalPattern('vi_VN').format(order.amount)} VND',
          emphasize: true,
        ),
        const SizedBox(height: 12),
        _Field(label: 'Nội dung thanh toán', value: order.orderInfo),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phương thức thanh toán',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cổng thanh toán $_portalName',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: _portalBrand, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isMomo && order.qrCodeUrl != null) ...[
          _qrPanel(order.qrCodeUrl!),
          const SizedBox(height: 12),
        ],
        if (_isMomo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showResultCodes,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.momo,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Xem mã kết quả MoMo'),
            ),
          ),
        Text(
          'Phòng: ${widget.room!.title}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  // MoMo paints the QR itself, so the app only shows the picture it links to.
  Widget _qrPanel(String qrCodeUrl) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Image.network(
          qrCodeUrl,
          height: 160,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.qr_code_2,
            size: 96,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quét mã bằng ứng dụng MoMo để thanh toán',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  void _showResultCodes() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Text(
            'Mã kết quả MoMo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'MoMo trả về mã này trong thông báo kết quả.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final entry in kMomoResultCodes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.momo,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  // Returned from the portal with a reference but no room in hand.
  Widget _referenceCard() => _Card(
    title: 'Thông tin thanh toán',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'Mã tham chiếu',
          value: widget.txnRef!,
          emphasize: true,
        ),
        const SizedBox(height: 12),
        Text(
          'Hoàn tất thanh toán rồi? Kết quả bên dưới cập nhật từ máy chủ.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _payButton() => FilledButton.icon(
    onPressed: _launching ? null : _openPortal,
    style: FilledButton.styleFrom(
      backgroundColor: _portalBrand,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: _launching
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.credit_card),
    label: Text(_launching ? 'Đang mở cổng thanh toán...' : 'Thanh toán ngay'),
  );

  Widget _cancelButton() => OutlinedButton.icon(
    onPressed: _cancelling ? null : _cancelDeposit,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.failure,
      side: const BorderSide(color: AppColors.failure, width: 1),
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: _cancelling
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.failure,
            ),
          )
        : const Icon(Icons.close),
    label: Text(_cancelling ? 'Đang hủy cọc...' : 'Hủy cọc'),
  );

  Widget _resultCard(PaymentResult result) {
    final settled = result.isSettled;
    final color = settled
        ? (result.status == 'PAID' ? AppColors.success : AppColors.failure)
        : AppColors.muted;
    return _Card(
      title: 'Trạng thái giao dịch',
      trailing: Icon(
        settled
            ? (result.status == 'PAID' ? Icons.check_circle : Icons.cancel)
            : Icons.hourglass_bottom,
        color: color,
        size: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.message,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _Pill(
                label: _stateLabel(result),
                background: _stateBackground(result),
                foreground: color,
              ),
              if (result.responseCode != null)
                _Pill(
                  label: 'Mã ${result.responseCode}',
                  background: AppColors.neutralSoft,
                  foreground: AppColors.ink,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow(
            label: 'Số tiền',
            value:
                '${NumberFormat.decimalPattern('vi_VN').format(result.amount)} VND',
          ),
          _DetailRow(label: 'Mã giao dịch', value: result.txnRef),
          _DetailRow(label: 'Ngân hàng', value: result.bankName),
          if (result.transactionNo != null)
            _DetailRow(
              label: 'Mã giao dịch ${_portalDisplayName(result.gateway)}',
              value: result.transactionNo!,
            ),
          if (result.payDate != null)
            _DetailRow(
              label: 'Thời gian thanh toán',
              value: _formatPayDate(result.payDate!),
            ),
        ],
      ),
    );
  }

  Widget _pendingNote() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warningSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: AppColors.warningIcon, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Đã mở cổng thanh toán? Quay lại ứng dụng để cập nhật trạng thái. '
            'Giao dịch chưa hoàn tất sẽ tự động kiểm tra lại.',
            style: TextStyle(
              color: AppColors.warningInk,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _serverSignedNote() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.shield_outlined, color: AppColors.muted, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Ứng dụng không chứa khóa bí mật. Đường dẫn thanh toán được máy chủ '
          'ký HMAC-${_isMomo ? 'SHA256' : 'SHA512'} và trả về cho app.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
        ),
      ),
    ],
  );

  // The three states the demo promises the student: paid, refused, and still
  // waiting on the portal. Only the first one may read as a booked room.
  static String _stateLabel(PaymentResult result) {
    if (!result.isSettled) return 'Đang xử lý';
    return result.status == 'PAID' ? 'Thành công' : 'Thất bại';
  }

  static Color _stateBackground(PaymentResult result) {
    if (!result.isSettled) return AppColors.neutralSoft;
    return result.status == 'PAID'
        ? AppColors.successSoft
        : AppColors.failureSoft;
  }

  Widget _debugCard() => _Card(
    title: 'Nhật ký cổng thanh toán',
    subtitle: 'Bản debug: yêu cầu và trả lời của cổng',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _debugLog)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              line,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    ),
  );

  String _formatPayDate(String value) {
    if (value.length != 14) return value;
    final year = value.substring(0, 4);
    final month = value.substring(4, 6);
    final day = value.substring(6, 8);
    final hour = value.substring(8, 10);
    final minute = value.substring(10, 12);
    final second = value.substring(12, 14);
    return '$day/$month/$year $hour:$minute:$second';
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.label, required this.brand});

  /// The portal's own short mark, as the header shows it.
  final String label;
  final Color brand;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: brand,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    ),
  );
}

/// One row of the portal chooser. The app makes no gateway decision of its own:
/// picking a row only says which portal the order should be opened through.
class _GatewayOption extends StatelessWidget {
  const _GatewayOption({
    required this.value,
    required this.selected,
    required this.brand,
    required this.mark,
    required this.name,
    required this.detail,
    required this.onSelect,
  });

  final String value;
  final bool selected;
  final Color brand;
  final String mark;
  final String name;
  final String detail;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onSelect(value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandSoft : Colors.white,
        border: Border.all(
          color: selected ? brand : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? brand : AppColors.subtle,
            size: 22,
          ),
          const SizedBox(width: 12),
          _BrandMark(label: mark, brand: brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.scrim,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: emphasize ? 17 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
