import 'package:flutter/material.dart';

import '../../rooms/domain/room.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({required this.room, super.key});

  final Room room;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Chat với ${room.landlordName ?? 'chủ trọ'}'),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'Nội dung chat chưa được đấu nối Firebase.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'roomId: ${room.id}\nlandlordId: ${room.landlordId ?? 'chưa có'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
