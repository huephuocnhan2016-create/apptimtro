import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../domain/conversation.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc trò chuyện')),
    body: FutureBuilder(
      future: ref.read(firebaseSignInProvider.future).then(
        (_) => ref.read(messageRepositoryProvider).conversations(),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được danh sách chat: ${apiErrorMessage(snapshot.error!)}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final conversations = snapshot.data!;
        if (conversations.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có cuộc trò chuyện nào.\nVào Mục yêu thích và bấm icon chat để bắt đầu.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: _Avatar(conversation: conversation),
                title: Text(
                  conversation.participantName ?? 'Người dùng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.roomTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (conversation.createdAt != null)
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(conversation.createdAt!.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () => context.push('/chats/thread', extra: conversation),
              ),
            );
          },
        );
      },
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final imageUrl = conversation.participantAvatarUrl ??
        conversation.roomImageUrl;
    if (imageUrl == null) {
      return CircleAvatar(
        child: Text(
          (conversation.participantName ?? '?').characters.first.toUpperCase(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const CircleAvatar(child: Icon(Icons.person_outline)),
      ),
    );
  }
}
