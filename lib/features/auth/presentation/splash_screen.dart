import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({this.from, super.key});

  /// Đường dẫn người dùng định mở trước khi bị đưa qua splash (vd. deep link).
  final String? from;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).setUser(user);
      ref.read(sessionRestoredProvider.notifier).markRestored();
      final from = widget.from;
      // Router sẽ tự đưa về /login nếu `from` cần đăng nhập mà chưa có user.
      if (from != null && from.startsWith('/') && !from.startsWith('/splash')) {
        context.go(from);
      } else {
        context.go(user == null ? '/welcome' : '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.house_rounded, size: 68, color: AppColors.brand),
          SizedBox(height: 12),
          Text(
            'Trọ Tốt',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}
