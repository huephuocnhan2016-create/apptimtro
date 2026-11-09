import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Màn lỗi dùng chung khi route thiếu dữ liệu hoặc đường dẫn không tồn tại.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48, color: AppColors.subtle),
            const SizedBox(height: AppSpace.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  );
}
