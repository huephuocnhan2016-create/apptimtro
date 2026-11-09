import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rooms/domain/room.dart';
import '../format.dart';
import 'app_network_image.dart';

/// Thẻ phòng trong danh sách (tìm phòng, yêu thích). Bấm vào mở chi tiết phòng.
class RoomCard extends StatelessWidget {
  const RoomCard({required this.room, this.onChat, super.key});

  final Room room;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: 6,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/rooms/${room.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 100,
            child: room.image == null
                ? const Icon(Icons.home_work_outlined)
                : AppNetworkImage(room.image!, width: 110, height: 100),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    room.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${formatVnd(room.price)}/tháng'),
                  Text(
                    room.status == 'DEPOSITED'
                        ? 'Đang cọc'
                        : 'Còn ${room.availableRooms} phòng',
                  ),
                ],
              ),
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
    ),
  );
}
