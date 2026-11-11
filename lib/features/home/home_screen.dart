import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error_message.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/room_card.dart';
import '../../shared/widgets/staggered_enter.dart';
import '../rooms/domain/room.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<Room>> _suggested;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _suggested = ref.read(roomRepositoryProvider).search();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Khám phá'),
            backgroundColor: AppColors.canvas,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.xl,
              ),
              child: TextField(
                readOnly: true,
                showCursor: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm theo khu vực, trường học',
                ),
                onTap: () => context.push('/rooms/search'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: Text('Gợi ý cho bạn', style: text.titleLarge),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xl),
              child: FutureBuilder<List<Room>>(
                future: _suggested,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _HomeError(
                      message:
                          'Không tải được gợi ý: ${apiErrorMessage(snapshot.error!)}',
                      onRetry: () => setState(_reload),
                    );
                  }
                  if (!snapshot.hasData) return const _HomeLoading();
                  return _Suggestions(rooms: snapshot.data!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const SizedBox(
        height: 220,
        child: EmptyStateView(
          message: 'Chưa có phòng nào được đăng.',
          icon: Icons.bedroom_parent_outlined,
          hint: 'Khi chủ trọ đăng tin mới, phòng sẽ hiện ở đây.',
        ),
      );
    }
    final shown = rooms.take(4).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          StaggeredEnter(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: RoomCard(room: shown[i]),
            ),
          ),
      ],
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 160,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: ErrorStateView(message: message, onRetry: onRetry),
  );
}
