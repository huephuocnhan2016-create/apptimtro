import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error_message.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/room_card.dart';
import '../../shared/widgets/staggered_enter.dart';
import '../auth/domain/user.dart';
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
    final isLandlord =
        ref.watch(currentUserProvider)?.role == UserRole.landlord;
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Gợi ý cho bạn', style: text.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => context.push('/rooms/search'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Lối tắt', style: text.titleLarge),
                  const SizedBox(height: AppSpace.md),
                  _ShortcutRow(
                    items: [
                      // /map là một tab: chuyển tab (go) để thanh điều hướng
                      // sáng đúng.
                      _Shortcut(
                        Icons.map_outlined,
                        'Bản đồ',
                        'Phòng gần bạn',
                        () => context.go('/map'),
                      ),
                      _Shortcut(
                        Icons.chat_bubble_outline,
                        'Tin nhắn',
                        'Trao đổi chủ trọ',
                        () => context.push('/chats'),
                      ),
                      if (isLandlord)
                        _Shortcut(
                          Icons.home_work_outlined,
                          'Quản lý',
                          'Đăng & sửa tin',
                          () => context.push('/landlord'),
                        ),
                    ],
                  ),
                ],
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

class _Shortcut {
  const _Shortcut(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.items});

  final List<_Shortcut> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < items.length - 1 ? AppSpace.md : 0,
              ),
              child: _ShortcutCard(shortcut: items[index], text: text),
            ),
          ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, required this.text});

  final _Shortcut shortcut;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: shortcut.onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(shortcut.icon, color: AppColors.brand),
            const SizedBox(height: AppSpace.lg),
            Text(shortcut.title, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(shortcut.subtitle, maxLines: 2, style: text.bodyMedium),
          ],
        ),
      ),
    ),
  );
}
