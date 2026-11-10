import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../../rooms/domain/room.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/room_card.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<List<Room>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = ref.read(roomRepositoryProvider).favorites();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Yêu thích'),
      actions: [
        IconButton(
          onPressed: () => setState(() {
            _favorites = ref.read(roomRepositoryProvider).favorites();
          }),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Room>>(
      future: _favorites,
      builder: (context, snapshot) => AsyncStateView<List<Room>>(
        snapshot: snapshot,
        errorPrefix: 'Không tải được mục yêu thích',
        onRetry: () => setState(() {
          _favorites = ref.read(roomRepositoryProvider).favorites();
        }),
        emptyMessage: 'Bạn chưa lưu phòng yêu thích nào.',
        emptyIcon: Icons.favorite_border,
        builder: (context, rooms) => ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Dismissible(
              key: ValueKey(room.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: Icon(
                  Icons.favorite_border,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              confirmDismiss: (_) async {
                try {
                  await ref.read(roomRepositoryProvider).unfavorite(room.id);
                  return true;
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Không thể bỏ yêu thích: ${apiErrorMessage(error)}',
                        ),
                      ),
                    );
                  }
                  return false;
                }
              },
              child: RoomCard(
                room: room,
                onChat: room.landlordId == null
                    ? null
                    : () => context.push('/chat', extra: room),
              ),
            );
          },
        ),
      ),
    ),
  );
}
