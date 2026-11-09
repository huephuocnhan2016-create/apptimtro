import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../domain/payment_order.dart';

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

  Future<void> _cancel(RoomDeposit deposit) async {
    if (_cancellingTxnRef != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đặt cọc?'),
        content: const Text('Phòng sẽ được mở lại cho người khác đặt cọc.'),
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
        IconButton(
          onPressed: () => setState(() {
            _deposits = ref.read(paymentApiProvider).deposits();
          }),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<RoomDeposit>>(
      future: _deposits,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được danh sách đặt cọc: '
                '${apiErrorMessage(snapshot.error!)}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Bạn chưa đặt cọc phòng nào.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final deposit = snapshot.data![index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: deposit.roomImage == null
                    ? const CircleAvatar(child: Icon(Icons.apartment_outlined))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          deposit.roomImage!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const CircleAvatar(
                            child: Icon(Icons.apartment_outlined),
                          ),
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
                      'Cọc ${NumberFormat.decimalPattern('vi_VN').format(deposit.amount)} đ'
                      '${deposit.payDate == null ? '' : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(deposit.payDate!.toLocal())}'}',
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
        );
      },
    ),
  );
}
