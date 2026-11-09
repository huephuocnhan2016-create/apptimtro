import 'package:flutter/material.dart';

import '../../../shared/widgets/confirm_dialog.dart';

/// Hộp thoại "Hủy đặt cọc?" — dùng chung cho màn thanh toán và danh sách cọc.
Future<bool> confirmCancelDeposit(BuildContext context) => confirmDialog(
  context,
  title: 'Hủy đặt cọc?',
  body: 'Phòng sẽ được mở lại cho người khác đặt cọc.',
  confirmLabel: 'Hủy cọc',
  cancelLabel: 'Giữ cọc',
  danger: true,
);
