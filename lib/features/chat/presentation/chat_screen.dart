import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../rooms/domain/room.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không gửi được tin nhắn.')),
        );
      }
    }
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
                stream: ref
                    .read(messageRepositoryProvider)
                    .messages(session.conversationId),
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
                  return ListView(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
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
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      tooltip: 'Gửi',
                      onPressed: () => _send(session),
                    ),
                  ],
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
        : DateFormat.Hm().format(message.createdAt!.toLocal());
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isMine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text),
            if (time.isNotEmpty)
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
