import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentOrder? _order;
  Timer? _timer;
  String? _error;
  bool _loading = true;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _createOrder() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _order = null;
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
      if (order.status == 'PENDING') {
        _timer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _checkStatus(),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tạo được yêu cầu thanh toán: ${apiErrorMessage(error)}';
      });
    }
  }

  Future<void> _checkStatus() async {
    final order = _order;
    if (order == null || _checkingStatus || order.status != 'PENDING') return;
    _checkingStatus = true;
    try {
      final status = await ref.read(paymentApiProvider).status(order.txnRef);
      if (!mounted) return;
      setState(() {
        _order = order.withStatus(status);
        _error = null;
      });
      if (status != 'PENDING') _timer?.cancel();
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
    appBar: AppBar(title: const Text('Thanh toán')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _order == null
        ? _errorView()
        : _paymentView(_order!),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'Không thể tạo yêu cầu thanh toán.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _createOrder, child: const Text('Thử lại')),
        ],
      ),
    ),
  );

  Widget _paymentView(PaymentOrder order) {
    final amount = NumberFormat.decimalPattern('vi_VN').format(order.amount);
    final statusText = switch (order.status) {
      'PAID' => 'Thanh toán thành công.',
      'FAILED' => 'Thanh toán thất bại.',
      'CANCELLED' => 'Yêu cầu thanh toán đã bị hủy.',
      _ => 'Đang chờ thanh toán. Trạng thái sẽ được kiểm tra tự động.',
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.room.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '$amount đ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        if (order.status == 'PENDING')
          Center(
            child: QrImageView(
              data: order.qrcontent,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 24),
        Text(statusText, textAlign: TextAlign.center),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
