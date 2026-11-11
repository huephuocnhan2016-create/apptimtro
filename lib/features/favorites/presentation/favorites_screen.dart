import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../rooms/domain/room.dart';
import '../../../shared/app_toast.dart';
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
        emptyHint: 'Bấm icon tim trên thẻ phòng để lưu lại và so sánh sau.',
        emptyAction: FilledButton.tonal(
          onPressed: () => context.push('/rooms/search'),
          child: const Text('Tìm phòng trọ'),
        ),
        builder: (context, rooms) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.xxxl,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Dismissible(
                key: ValueKey(room.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: AppColors.failureSoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpace.xl),
                  child: const Icon(
                    Icons.favorite_border,
                    color: AppColors.failure,
                  ),
                ),
                confirmDismiss: (_) async {
                  try {
                    await ref.read(roomRepositoryProvider).unfavorite(room.id);
                    return true;
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).snack(
                        'Không thể bỏ yêu thích: ${apiErrorMessage(error)}',
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
              ),
            );
          },
        ),
      ),
    ),
  );
}
