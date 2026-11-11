import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Một khối nội dung có tiêu đề — trong Android đây là `Card` chứa các dòng
/// `TextView`/`ListView`, không tự vẽ bóng hay bo góc riêng.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.background,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// Tô nền khi khối tự mang một trạng thái (thành công, thất bại).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// Dòng "nhãn — giá trị": nhãn cột trái, giá trị cột phải, giống hàng
/// `TextView` label/value trong Android.
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.value,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasize
                  ? theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: AppTypography.tabularFigures,
                    )
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng chi tiết gọn trong thẻ trạng thái.
class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

/// Nhãn trạng thái dùng `Chip` của Material thay vì pill tự vẽ.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    labelStyle: TextStyle(
      color: foreground,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    backgroundColor: background,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.xs,
    ),
  );
}
