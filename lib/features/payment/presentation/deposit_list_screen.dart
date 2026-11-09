import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../domain/payment_order.dart';
import 'confirm_cancel_deposit.dart';

class DepositListScreen extends ConsumerStatefulWidget {
  const DepositListScreen({super.key});

  @override
  ConsumerState<DepositListScreen> createState() => _DepositListScreenState();
}

class _DepositListScreenState extends ConsumerState<DepositListScreen> {
  late Future<List<RoomDeposit>> _deposits;
  String? _cancellingTxnRef;

  @override
  void initState() {
    super.initState();
    _deposits = ref.read(paymentApiProvider).deposits();
  }

  void _reload() => setState(() {
    _deposits = ref.read(paymentApiProvider).deposits();
  });

  Future<void> _cancel(RoomDeposit deposit) async {
    if (_cancellingTxnRef != null) return;
    final confirmed = await confirmCancelDeposit(context);
    if (!confirmed || !mounted) return;
    setState(() => _cancellingTxnRef = deposit.txnRef);
    try {
      await ref.read(paymentApiProvider).cancel(deposit.txnRef);
      if (!mounted) return;
      setState(() {
        _cancellingTxnRef = null;
        _deposits = ref.read(paymentApiProvider).deposits();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã hủy đặt cọc.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _cancellingTxnRef = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không hủy được đặt cọc: ${apiErrorMessage(error)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Phòng đã đặt cọc'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<RoomDeposit>>(
      future: _deposits,
      builder: (context, snapshot) => AsyncStateView<List<RoomDeposit>>(
        snapshot: snapshot,
        errorPrefix: 'Không tải được danh sách đặt cọc',
        onRetry: _reload,
        emptyMessage: 'Bạn chưa đặt cọc phòng nào.',
        emptyIcon: Icons.receipt_long_outlined,
        builder: (context, deposits) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: deposits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final deposit = deposits[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: deposit.roomImage == null
                    ? const CircleAvatar(child: Icon(Icons.apartment_outlined))
                    : AppNetworkImage(
                        deposit.roomImage!,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(8),
                        errorWidget: const CircleAvatar(
                          child: Icon(Icons.apartment_outlined),
                        ),
                      ),
                title: Text(
                  deposit.roomTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deposit.roomAddress),
                    const SizedBox(height: 4),
                    Text(
                      'Cọc ${formatVnd(deposit.amount)}'
                      '${deposit.payDate == null ? '' : ' · ${formatDateVn(deposit.payDate!)}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _cancellingTxnRef == deposit.txnRef
                          ? null
                          : () => _cancel(deposit),
                      child: Text(
                        _cancellingTxnRef == deposit.txnRef
                            ? 'Đang hủy…'
                            : 'Hủy cọc',
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => context.push('/rooms/${deposit.roomId}'),
              ),
            );
          },
        ),
      ),
    ),
  );
}
