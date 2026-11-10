import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../format.dart';

/// 5 ngôi sao cho một điểm trung bình 0–5.
class RatingStars extends StatelessWidget {
  const RatingStars({required this.rating, this.size = 14, super.key});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final half = rating - full >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && half
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
            size: size,
            color: AppColors.star,
          ),
      ],
    );
  }
}

/// Sao + điểm dạng gọn, dùng trên thẻ phòng và tiêu đề khối đánh giá.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    required this.average,
    required this.count,
    this.onImage = false,
    super.key,
  });

  final double average;
  final int count;

  /// Trên nền ảnh thì chữ trắng, sao vẫn vàng.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = onImage ? AppColors.onBrand : AppColors.ink;
    final mutedColor = onImage ? AppColors.onBrandMuted : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: AppColors.star),
        const SizedBox(width: AppSpace.xs),
        Text(
          formatNumber(average),
          style: text.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(' ($count)', style: text.bodyMedium?.copyWith(color: mutedColor)),
      ],
    );
  }
}
