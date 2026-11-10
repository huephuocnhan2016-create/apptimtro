import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rooms/domain/room.dart';
import '../format.dart';
import 'app_network_image.dart';

/// Một item trong danh sách theo kiểu Android: `Card` + `InkWell`, ảnh bìa
/// nằm trên, các dòng chữ bên dưới. Bấm vào mở chi tiết phòng.
class RoomCard extends StatelessWidget {
  const RoomCard({required this.room, this.onChat, super.key});

  final Room room;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/rooms/${room.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (room.image == null)
              const SizedBox(
                height: 140,
                child: Icon(Icons.home_work_outlined, size: 48),
              )
            else
              AppNetworkImage(room.image!, height: 160),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    room.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatVnd(room.price)}/tháng',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        room.status == 'DEPOSITED'
                            ? 'Đang cọc'
                            : 'Còn ${room.availableRooms} phòng',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
