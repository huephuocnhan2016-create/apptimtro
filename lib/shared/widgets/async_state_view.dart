import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.emptyHint,
    this.emptyAction,
    this.isEmpty,
    super.key,
  });

  final AsyncSnapshot<T> snapshot;

  /// Đổi `AsyncValue` (Riverpod) sang `AsyncSnapshot` để dùng chung widget này.
  /// Đang tải lại mà đã có dữ liệu cũ thì vẫn hiện dữ liệu cũ.
  static AsyncSnapshot<V> snapshotOf<V>(AsyncValue<V> value) {
    if (value.hasError) {
      return AsyncSnapshot.withError(
        ConnectionState.done,
        value.error!,
        value.stackTrace ?? StackTrace.empty,
      );
    }
    if (value.hasValue) {
      return AsyncSnapshot.withData(ConnectionState.done, value.requireValue);
    }
    return const AsyncSnapshot.waiting();
  }

  final Widget Function(BuildContext context, T data) builder;

  /// Ví dụ `Không tải được phòng` → hiện `Không tải được phòng: (lý do)`.
  final String? errorPrefix;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final IconData? emptyIcon;
  final String? emptyHint;
  final Widget? emptyAction;

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
    if (empty) {
      return EmptyStateView(
        message: emptyMessage,
        icon: emptyIcon,
        hint: emptyHint,
        action: emptyAction,
      );
    }
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
          const _StateIcon(
            icon: Icons.cloud_off_rounded,
            color: AppColors.failure,
            background: AppColors.failureSoft,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.xl),
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
  const EmptyStateView({
    required this.message,
    this.icon,
    this.hint,
    this.action,
    super.key,
  });

  final String message;
  final IconData? icon;

  /// Dòng dẫn dắt ngắn dưới thông báo — state rỗng là chỗ để chỉ đường, không
  /// phải chỗ để báo "trống".
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              _StateIcon(
                icon: icon!,
                color: AppColors.muted,
                background: AppColors.surfaceAlt,
              ),
              const SizedBox(height: AppSpace.lg),
            ],
            Text(message, textAlign: TextAlign.center, style: text.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Biểu tượng trạng thái đặt trong ô tròn mềm — một nhịp thị giác cho mọi
/// state rỗng/lỗi thay vì icon trơ trên nền trắng.
class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, size: 28, color: color),
  );
}
