import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../domain/conversation.dart';

/// Danh sách cuộc trò chuyện. Trước đây future được tạo ngay trong build nên
/// mỗi lần vẽ lại là gọi API lại; giờ chỉ tải lại khi `ref.invalidate`.
final conversationsProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
      await ref.watch(firebaseSignInProvider.future);
      return ref.watch(messageRepositoryProvider).conversations();
    });

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc trò chuyện')),
    body: AsyncStateView<List<ChatConversation>>(
        snapshot: AsyncStateView.snapshotOf(ref.watch(conversationsProvider)),
        errorPrefix: 'Không tải được danh sách chat',
        onRetry: () => ref.invalidate(conversationsProvider),
        emptyMessage:
            'Chưa có cuộc trò chuyện nào.\nVào Mục yêu thích và bấm icon chat để bắt đầu.',
        emptyIcon: Icons.chat_bubble_outline,
        builder: (context, conversations) => RefreshIndicator(
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        formatDateVn(conversation.createdAt!),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () => context.push('/chats/thread', extra: conversation),
              ),
            );
          },
          ),
        ),
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
    return AppNetworkImage(
      imageUrl,
      width: 48,
      height: 48,
      borderRadius: BorderRadius.circular(24),
      errorWidget: const CircleAvatar(child: Icon(Icons.person_outline)),
    );
  }
}
