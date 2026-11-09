import 'package:flutter/material.dart';

import '../../core/network/api_error_message.dart';
import '../../core/theme/app_theme.dart';

/// Vẽ 4 trạng thái của một FutureBuilder/StreamBuilder: đang tải, lỗi (kèm nút
/// "Thử lại"), rỗng, và có dữ liệu.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.snapshot,
    required this.builder,
    this.errorPrefix,
    this.onRetry,
    this.emptyMessage = 'Chưa có dữ liệu.',
    this.emptyIcon,
    this.isEmpty,
    super.key,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(BuildContext context, T data) builder;

  /// Ví dụ `Không tải được phòng` → hiện `Không tải được phòng: (lý do)`.
  final String? errorPrefix;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final IconData? emptyIcon;

  /// Mặc định: rỗng khi dữ liệu là danh sách không có phần tử.
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      final reason = apiErrorMessage(snapshot.error!);
      return ErrorStateView(
        message: errorPrefix == null ? reason : '$errorPrefix: $reason',
        onRetry: onRetry,
      );
    }
    if (!snapshot.hasData) return const LoadingStateView();
    final data = snapshot.data as T;
    final empty = isEmpty?.call(data) ?? (data is Iterable && data.isEmpty);
    if (empty) return EmptyStateView(message: emptyMessage, icon: emptyIcon);
    return builder(context, data);
  }
}

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.muted),
          const SizedBox(height: AppSpace.md),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    ),
  );
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: AppColors.subtle),
            const SizedBox(height: AppSpace.md),
          ],
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
