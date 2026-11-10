import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rooms/domain/room.dart';
import '../format.dart';
import 'app_network_image.dart';
import 'pressable_scale.dart';
import 'rating_stars.dart';

/// Thẻ phòng dạng ảnh-first: ảnh chiếm phần trên, giá nằm trên lớp phủ tối để
/// đọc được trên mọi bức ảnh, phần chữ chỉ còn tiêu đề — địa chỉ — sao/diện tích.
class RoomCard extends StatelessWidget {
  const RoomCard({required this.room, this.onChat, super.key});

  final Room room;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rating = room.ratingAverage;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: PressableScale(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/rooms/${room.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                if (room.image == null)
                  const SizedBox(
                    height: 156,
                    child: Icon(Icons.home_work_outlined, size: 40),
                  )
                else
                  AppNetworkImage(
                    room.image!,
                    width: double.infinity,
                    height: 156,
                  ),
                // Lớp phủ chỉ ở nửa dưới ảnh, đủ cho giá trắng nổi lên.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.scrim.withValues(alpha: 0.0),
                          AppColors.scrim.withValues(alpha: 0.72),
                        ],
                        stops: const [0.45, 0.62, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpace.lg,
                  bottom: AppSpace.md,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatVnd(room.price),
                          style: text.titleMedium?.copyWith(
                            color: AppColors.onBrand,
                            fontFeatures: AppTypography.tabularFigures,
                          ),
                        ),
                        TextSpan(
                          text: '/tháng',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.onBrandMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (room.status == 'DEPOSITED')
                  Positioned(
                    right: AppSpace.md,
                    top: AppSpace.md,
                    child: _OverlayLabel(label: 'Đang cọc'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      if (rating != null && room.ratingCount > 0) ...[
                        RatingBadge(average: rating, count: room.ratingCount),
                        const SizedBox(width: AppSpace.md),
                      ],
                      Text(
                        '${room.area.toStringAsFixed(0)} m²',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Còn ${room.availableRooms} phòng',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (onChat != null)
                        IconButton(
                          tooltip: 'Nhắn tin với chủ trọ',
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: onChat,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ trên ảnh: nền trắng mờ + chữ đậm, không cần màu riêng cho trạng thái.
class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 2,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
