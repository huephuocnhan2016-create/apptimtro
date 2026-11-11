import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../rooms/domain/room.dart';
import '../domain/momo_result_codes.dart';
import '../domain/payment_order.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/section_card.dart';
import 'confirm_cancel_deposit.dart';
import 'payment_controller.dart';
import 'widgets/gateway_widgets.dart';

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
  late final PaymentArgs _args = (
    roomId: widget.room?.id,
    txnRef: widget.txnRef,
  );

  /// State mới nhất, gán ở đầu [build]; các hàm vẽ bên dưới đọc từ đây.
  late PaymentState _s;

  PaymentController get _controller =>
      ref.read(paymentControllerProvider(_args).notifier);

  /// Viết hoa, như cổng tự ghi tên trên trang thanh toán.
  String get _portalLabel => _s.isMomo ? 'MOMO' : 'VNPAY';

  /// Tên cổng như người dùng đọc.
  String get _portalName => portalDisplayName(_s.activeGateway);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cổng mở trong tab trình duyệt, nên quay lại app chính là tín hiệu
    // "tôi xong rồi" mà app bắt được không cần deep link.
    if (state == AppLifecycleState.resumed) _controller.checkStatus();
  }

  Future<void> _cancelDeposit() async {
    if (_s.activeTxnRef == null || _s.cancelling) return;
    final confirmed = await confirmCancelDeposit(context);
    if (!confirmed || !mounted) return;
    await _controller.cancel();
  }

  /// Cổng mở link nên màn này thường là route duy nhất — không có gì để pop.
  Future<void> _leave() async {
    if (!mounted) return;
    if (!await Navigator.of(context).maybePop()) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    _s = ref.watch(paymentControllerProvider(_args));
    final showPay =
        _s.order != null && (_s.result == null || !_s.result!.isSettled);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_portalLabel),
        actions: [
          if (_isSandbox)
            const Padding(
              padding: EdgeInsets.only(right: AppSpace.md),
              child: Chip(
                label: Text('SANDBOX'),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      bottomNavigationBar: showPay ? _payBar() : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          Text(
            'Giao dịch của bạn được bảo vệ bởi $_portalName.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          if (_s.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.xxxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _FlowSteps(step: _step),
            const SizedBox(height: AppSpace.lg),
            if (_s.order == null && widget.txnRef == null)
              _s.error != null ? _errorCard() : _gatewayPicker()
            else ...[
              if (_s.order != null) _infoCard(_s.order!) else _referenceCard(),
              if (_s.order != null &&
                  (_s.result == null || !_s.result!.isSettled))
                _gatewaySwitch(),
              if (_s.canCancel) _cancelButton(),
              if (_s.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Text(
                    _s.error!,
                    style: TextStyle(color: AppColors.failure, fontSize: 13),
                  ),
                ),
              if (_s.result != null) _resultCard(_s.result!),
              if (_s.result == null || !_s.result!.isSettled) _pendingNote(),
              if (_s.debugLog.isNotEmpty) _debugCard(),
            ],
          ],
          const SizedBox(height: AppSpace.md),
          _serverSignedNote(),
        ],
      ),
    );
  }

  /// Bước hiện tại của luồng cọc: 0 chọn cổng, 1 trả tiền, 2 kết quả.
  /// Quay về từ link của cổng thì màn này chỉ có txnRef, không có đơn cục bộ,
  /// nên phải xét txnRef chứ không xét đơn — nếu không thanh tiến trình nhảy
  /// ngược về "Chọn cổng" dù giao dịch đã thành công.
  int get _step {
    if (_s.result != null && _s.result!.isSettled) return 2;
    if (_s.order == null && _s.activeTxnRef == null) return 0;
    return 1;
  }

  bool get _isSandbox {
    final order = _s.order;
    if (order == null) return false;
    // Both the shared dev checkout page and MoMo's test host stand in for a
    // portal that no real money moves through.
    return order.payUrl.contains('sandbox') ||
        order.payUrl.contains('/dev/') ||
        order.payUrl.contains('test-payment.momo.vn');
  }

  Widget _errorCard() => SectionCard(
    title: 'Không tạo được yêu cầu đặt cọc',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_s.error != null)
          Text(
            _s.error!,
            style: const TextStyle(color: AppColors.failure, fontSize: 13),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _controller.createOrder,
          child: const Text('Thử lại'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _controller.chooseAnotherGateway,
          child: const Text('Chọn cổng khác'),
        ),
      ],
    ),
  );

  Widget _gatewayPicker() => SectionCard(
    title: 'Chọn cổng thanh toán',
    subtitle: 'App tạo yêu cầu sau khi bạn chọn, chưa trừ tiền ở bước này',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GatewayOption(
          value: 'VNPAY',
          selected: _s.gateway == 'VNPAY',
          brand: AppColors.brand,
          name: 'VNPay',
          detail: 'Chuyển khoản ngân hàng, ví VNPay, thẻ nội địa',
          onSelect: _controller.selectGateway,
        ),
        const Divider(height: 1),
        GatewayOption(
          value: 'MOMO',
          selected: _s.gateway == 'MOMO',
          brand: AppColors.momo,
          name: 'MoMo',
          detail: 'Ví MoMo, QR MoMo, thẻ quốc tế',
          onSelect: _controller.selectGateway,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _controller.createOrder,
          child: Text('Thanh toán qua $_portalName'),
        ),
      ],
    ),
  );

  Widget _gatewaySwitch() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: _controller.chooseAnotherGateway,
      icon: const Icon(Icons.swap_horiz),
      label: const Text('Đổi cổng thanh toán'),
    ),
  );

  Widget _infoCard(PaymentOrder order) => SectionCard(
    title: 'Thông tin thanh toán',
    subtitle: 'Kiểm tra thông tin trước khi tiếp tục',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountHero(
          amount: formatVnd(order.amount, unit: 'VND'),
          roomTitle: widget.room?.title,
        ),
        const SizedBox(height: AppSpace.md),
        LabeledField(label: 'Nội dung thanh toán', value: order.orderInfo),
        LabeledField(
          label: 'Phương thức thanh toán',
          value: 'Cổng thanh toán $_portalName',
        ),
        if (_s.isMomo && order.qrCodeUrl != null) _qrPanel(order.qrCodeUrl!),
        if (_s.isMomo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showResultCodes,
              icon: const Icon(Icons.help_outline),
              label: const Text('Xem mã kết quả MoMo'),
            ),
          ),
      ],
    ),
  );

  // MoMo paints the QR itself, so the app only shows the picture it links to.
  Widget _qrPanel(String qrCodeUrl) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Image.network(
            qrCodeUrl,
            height: 160,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.qr_code_2, size: 96, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          const Text('Quét mã bằng ứng dụng MoMo để thanh toán'),
        ],
      ),
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
          Text(
            'Mã kết quả MoMo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text('MoMo trả về mã này trong thông báo kết quả.'),
          const Divider(),
          for (final entry in kMomoResultCodes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  // Returned from the portal with a reference but no room in hand.
  Widget _referenceCard() => SectionCard(
    title: 'Thông tin thanh toán',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Mã tham chiếu',
          value: widget.txnRef!,
          emphasize: true,
        ),
        const Text(
          'Hoàn tất thanh toán rồi? Kết quả bên dưới cập nhật từ máy chủ.',
        ),
      ],
    ),
  );

  /// Nút chính nằm dính đáy màn hình — đúng vùng ngón cái, vì đây là bước
  /// người dùng đang chờ để bấm.
  Widget _payBar() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.sm,
          ),
          child: _payButton(),
        ),
      ),
    );
  }

  Widget _payButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: _s.launching ? null : _controller.openPortal,
      icon: _s.launching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.credit_card),
      label: Text(
        _s.launching ? 'Đang mở cổng thanh toán...' : 'Thanh toán ngay',
      ),
    ),
  );

  Widget _cancelButton() => OutlinedButton.icon(
    onPressed: _s.cancelling ? null : _cancelDeposit,
    style: OutlinedButton.styleFrom(foregroundColor: AppColors.failure),
    icon: _s.cancelling
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.failure,
            ),
          )
        : const Icon(Icons.close),
    label: Text(_s.cancelling ? 'Đang hủy cọc...' : 'Hủy cọc'),
  );

  Widget _resultCard(PaymentResult result) {
    final settled = result.isSettled;
    final color = settled
        ? (result.status == 'PAID' ? AppColors.success : AppColors.failure)
        : AppColors.muted;
    return SectionCard(
      title: 'Trạng thái giao dịch',
      background: settled
          ? (result.status == 'PAID'
                ? AppColors.successSoft
                : AppColors.failureSoft)
          : AppColors.neutralSoft,
      trailing: Icon(
        settled
            ? (result.status == 'PAID' ? Icons.check_circle : Icons.cancel)
            : Icons.hourglass_bottom,
        color: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.message,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: _stateLabel(result),
                background: _stateBackground(result),
                foreground: color,
              ),
              if (result.responseCode != null)
                StatusPill(
                  label: 'Mã ${result.responseCode}',
                  background: AppColors.neutralSoft,
                  foreground: AppColors.ink,
                ),
            ],
          ),
          DetailRow(
            label: 'Số tiền',
            value: formatVnd(result.amount, unit: 'VND'),
          ),
          DetailRow(label: 'Mã giao dịch', value: result.txnRef),
          DetailRow(label: 'Ngân hàng', value: result.bankName),
          if (result.transactionNo != null)
            DetailRow(
              label: 'Mã giao dịch ${portalDisplayName(result.gateway)}',
              value: result.transactionNo!,
            ),
          if (result.payDate != null)
            DetailRow(
              label: 'Thời gian thanh toán',
              value: formatGatewayPayDate(result.payDate!),
            ),
        ],
      ),
    );
  }

  Widget _pendingNote() => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Đã mở cổng thanh toán?'),
      subtitle: const Text(
        'Quay lại ứng dụng để cập nhật trạng thái. '
        'Giao dịch chưa hoàn tất sẽ tự động kiểm tra lại.',
      ),
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
          'ký HMAC-${_s.isMomo ? 'SHA256' : 'SHA512'} và trả về cho app.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
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

  Widget _debugCard() => SectionCard(
    title: 'Nhật ký cổng thanh toán',
    subtitle: 'Bản debug: yêu cầu và trả lời của cổng',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _s.debugLog)
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
}

/// Ba bước của một lần đặt cọc, vẽ bằng dòng thời gian thay vì đoạn văn:
/// người dùng nhìn là biết mình đang đứng ở đâu và còn lại gì.
class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.step});

  /// 0 = chọn cổng, 1 = trả tiền, 2 = kết quả.
  final int step;

  static const _labels = ['Chọn cổng', 'Trả tiền', 'Kết quả'];

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < _labels.length; index++) ...[
        if (index > 0)
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.enter,
              curve: AppMotion.easeOut,
              height: 2,
              margin: const EdgeInsets.only(top: 11),
              color: index <= step ? AppColors.brand : AppColors.border,
            ),
          ),
        _StepDot(index: index, step: step, label: _labels[index]),
      ],
    ],
  );
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.step,
    required this.label,
  });

  final int index;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final done = index < step;
    final current = index == step;
    final color = done || current ? AppColors.brand : AppColors.subtle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || current ? AppColors.brand : AppColors.surface,
            border: Border.all(
              color: done || current ? AppColors.brand : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: done ? 16 : 6,
            color: done || current ? AppColors.onBrand : color,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: current ? AppColors.brand : AppColors.muted,
            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Số tiền là con số người dùng cần đọc to nhất trên màn thanh toán.
class _AmountHero extends StatelessWidget {
  const _AmountHero({required this.amount, this.roomTitle});

  final String amount;
  final String? roomTitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Số tiền thanh toán',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.brandDark),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          amount,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontFeatures: AppTypography.tabularFigures),
        ),
        if (roomTitle != null) ...[
          const SizedBox(height: 2),
          Text(roomTitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    ),
  );
}
