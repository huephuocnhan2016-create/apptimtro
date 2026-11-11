import 'package:flutter/material.dart';

/// Kiểu thông báo duy nhất của app: SnackBar chữ thuần, không nút bấm.
/// Dùng `ScaffoldMessenger.of(context).snack('...')`; nếu đã rời khỏi màn
/// (sau `context.go`) thì giữ `final messenger = ScaffoldMessenger.of(context)`
/// trước đó và gọi `messenger.snack('...')`.
extension AppSnack on ScaffoldMessengerState {
  void snack(String message) => showSnackBar(SnackBar(content: Text(message)));
}
