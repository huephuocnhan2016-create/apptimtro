import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Hộp thoại xác nhận dùng chung. Trả `true` chỉ khi người dùng bấm nút xác nhận.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Đồng ý',
  String cancelLabel = 'Hủy',
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.failure,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
