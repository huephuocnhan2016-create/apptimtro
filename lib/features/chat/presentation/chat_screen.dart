import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../rooms/domain/room.dart';
import '../../../shared/app_toast.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../domain/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.room, super.key})
    : conversationId = null,
      peerUid = null,
      peerName = null,
      roomId = null;

  const ChatScreen.withConversation({
    required this.conversationId,
    required this.peerUid,
    required this.peerName,
    this.roomId,
    super.key,
  }) : room = null;

  final Room? room;
  final String? conversationId;
  final String? peerUid;
  final String? peerName;
  final String? roomId;

  String get resolvedPeerName => room?.landlordName ?? peerName ?? 'chủ trọ';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatSession {
  const _ChatSession({required this.myUid, required this.conversationId});

  final String myUid;
  final String conversationId;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  late final Future<_ChatSession> _session;

  @override
  void initState() {
    super.initState();
    _session = _openSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_ChatSession> _openSession() async {
    final user = await ref.read(firebaseSignInProvider.future);
    if (user == null) {
      throw StateError('Chưa đăng nhập Firebase để chat.');
    }
    final repo = ref.read(messageRepositoryProvider);
    final roomId = widget.room?.id ?? widget.roomId;
    final peerUid = widget.room?.landlordId ?? widget.peerUid;
    var conversationId = widget.conversationId;
    if (conversationId == null) {
      conversationId = await repo.openConversation(
        roomId: roomId!,
        landlordId: peerUid!,
        myUid: user.uid,
      );
    } else if (roomId != null && peerUid != null) {
      await repo.ensureConversationDoc(
        conversationId,
        participantIds: [user.uid, peerUid],
        roomId: roomId,
      );
    }
    return _ChatSession(myUid: user.uid, conversationId: conversationId);
  }

  Future<void> _send(_ChatSession session) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref
          .read(messageRepositoryProvider)
          .send(session.conversationId, session.myUid, text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).snack('Không gửi được tin nhắn.');
      }
    }
  }

  Stream<List<Message>>? _messages;
  String? _messagesConversationId;

  /// Mở stream Firestore một lần cho mỗi cuộc trò chuyện. Gọi thẳng
  /// `messages(id)` trong build thì mỗi lần vẽ lại là một subscription mới.
  Stream<List<Message>> _messagesFor(String conversationId) {
    if (_messages == null || _messagesConversationId != conversationId) {
      _messagesConversationId = conversationId;
      _messages = ref.read(messageRepositoryProvider).messages(conversationId);
    }
    return _messages!;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Chat với ${widget.resolvedPeerName}')),
    body: FutureBuilder(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không mở được cuộc trò chuyện: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final session = snapshot.data!;
        return Column(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: _messagesFor(session.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Lỗi tải tin nhắn: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final messages = snapshot.data ?? const <Message>[];
                  if (messages.isEmpty) {
                    return const EmptyStateView(
                      message: 'Chưa có tin nhắn nào.',
                      icon: Icons.forum_outlined,
                      hint: 'Hỏi chủ trọ về giá, giờ xem phòng và cọc để mở đầu câu chuyện.',
                    );
                  }
                  return ListView(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.sm,
                    ),
                    children: [
                      for (final message in messages)
                        _MessageBubble(
                          message: message,
                          isMine: message.senderId == session.myUid,
                        ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.xs,
                    AppSpace.md,
                    AppSpace.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Nhắn tin…',
                          ),
                          onSubmitted: (_) => _send(session),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        tooltip: 'Gửi',
                        onPressed: () => _send(session),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = message.createdAt == null
        ? (message.pending ? 'đang gửi…' : '')
        : formatTimeVn(message.createdAt!);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        // Bubble ôm lấy chữ: tin ngắn mà chiếm hết 82% ngang thì khoảng trống
        // trong bubble lớn hơn cả nội dung.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            // Bo góc bất đối xứng ở góc gần tên người gửi: nhìn bubble là biết
            // ai nói, không phải đọc màu.
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
              bottomRight: Radius.circular(
                isMine ? AppRadius.sm : AppRadius.lg,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.text),
              if (time.isNotEmpty)
                Text(time, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
