import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../../rooms/domain/room.dart';
import '../domain/payment_order.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({required this.room, super.key});

  final Room room;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  static const _background = Color(0xFFF2F5FB);
  static const _brand = Color(0xFF1A5CFF);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _success = Color(0xFF16A34A);
  static const _failure = Color(0xFFDC2626);

  PaymentOrder? _order;
  PaymentResult? _result;
  Timer? _timer;
  String? _error;
  bool _loading = true;
  bool _checkingStatus = false;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOrder();
  }

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
          .createOrder(widget.room.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
      if (order.status == 'PENDING') _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tạo được yêu cầu đặt cọc: ${apiErrorMessage(error)}';
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
    var opened = true;
    try {
      opened = await launchUrl(
        Uri.parse(order.payUrl),
        mode: LaunchMode.inAppBrowserView,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _launching = false;
      if (!opened) _error = 'Không mở được cổng thanh toán VNPAY.';
    });
  }

  Future<void> _checkStatus() async {
    final order = _order;
    if (order == null || _checkingStatus) return;
    if (_result?.isSettled ?? false) return;
    _checkingStatus = true;
    try {
      final result = await ref.read(paymentApiProvider).status(order.txnRef);
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
      });
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
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
                else if (_order == null)
                  _errorCard()
                else ...[
                  _infoCard(_order!),
                  const SizedBox(height: 16),
                  if (_result == null || !_result!.isSettled) _payButton(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _failure, fontSize: 13),
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
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, color: _ink),
        ),
        const _BrandMark(),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VNPAY',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.1,
              ),
            ),
            Text(
              'THANH TOÁN AN TOÀN',
              style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 0.6),
            ),
          ],
        ),
        const Spacer(),
        if (_isSandbox)
          const _Pill(
            label: 'SANDBOX',
            background: Color(0xFFFEF3C7),
            foreground: Color(0xFF92400E),
          ),
      ],
    ),
  );

  bool get _isSandbox {
    final order = _order;
    if (order == null) return false;
    return order.payUrl.contains('sandbox') || order.payUrl.contains('/dev/');
  }

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A5CFF), Color(0xFF0B3FBF)],
      ),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(
          label: 'CÔNG THANH TOÁN TRỰC TUYẾN',
          background: Color(0x33FFFFFF),
          foreground: Colors.white,
        ),
        SizedBox(height: 14),
        Text(
          'Thanh toán nhanh chóng,\nan tâm tuyệt đối.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Giao dịch của bạn được bảo vệ bởi VNPAY.',
          style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _HeroBadge(icon: Icons.lock_outline, label: 'Bảo mật'),
            SizedBox(width: 8),
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
          Text(_error!, style: const TextStyle(color: _failure, fontSize: 13)),
        const SizedBox(height: 14),
        FilledButton(onPressed: _createOrder, child: const Text('Thử lại')),
      ],
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
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phương thức thanh toán',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cổng thanh toán VNPAY',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: _brand, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Phòng: ${widget.room.title}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _payButton() => FilledButton.icon(
    onPressed: _launching ? null : _openPortal,
    style: FilledButton.styleFrom(
      backgroundColor: _brand,
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

  Widget _resultCard(PaymentResult result) {
    final settled = result.isSettled;
    final color = settled
        ? (result.status == 'PAID' ? _success : _failure)
        : _muted;
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
          if (result.responseCode != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _Pill(
                  label: 'Mã ${result.responseCode}',
                  background: const Color(0xFFF1F5F9),
                  foreground: _ink,
                ),
              ],
            ),
          ],
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
              label: 'Mã giao dịch VNPAY',
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
      color: const Color(0xFFFFFBE6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Đã mở cổng thanh toán? Quay lại ứng dụng để cập nhật trạng thái. '
            'Giao dịch chưa hoàn tất sẽ tự động kiểm tra lại.',
            style: TextStyle(
              color: Color(0xFF92400E),
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
      const Icon(Icons.shield_outlined, color: _muted, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Ứng dụng không chứa Hash Secret. Đường dẫn thanh toán được máy chủ '
          'ký HMAC-SHA512 và trả về cho app.',
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
      ),
    ],
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
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF1A5CFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'VN',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
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
      color: const Color(0x22000000),
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
          color: const Color(0x0F0F172A),
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
                  color: _cardMuted,
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
            style: const TextStyle(color: _cardMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

const _cardMuted = Color(0xFF64748B);

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
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _cardMuted, fontSize: 12),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: emphasize ? 17 : 13,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
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
            style: const TextStyle(color: _cardMuted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
