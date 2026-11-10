import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/section_card.dart';
import '../../rooms/domain/room.dart';

class LandlordDashboardScreen extends StatelessWidget {
  const LandlordDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý phòng trọ')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        Text(
          'Phòng của bạn đang hiển thị với sinh viên',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.xl),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _NavTile(
                icon: Icons.meeting_room_outlined,
                title: 'Phòng của tôi',
                subtitle: 'Quản lý tin đăng và số phòng còn trống',
                onTap: () => context.push('/landlord/rooms'),
              ),
              const Divider(height: 1),
              _NavTile(
                icon: Icons.add_home_outlined,
                title: 'Đăng phòng mới',
                subtitle: 'Thêm một tin đăng để sinh viên tìm thấy',
                onTap: () => context.push('/landlord/rooms/add'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: _IconBadge(icon: icon),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right, color: AppColors.subtle),
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: AppColors.brand, size: 22),
  );
}

class MyRoomsScreen extends ConsumerStatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  ConsumerState<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends ConsumerState<MyRoomsScreen> {
  late Future<List<Room>> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = ref.read(roomRepositoryProvider).myRooms();
  }

  void _reload() => setState(() {
    _rooms = ref.read(roomRepositoryProvider).myRooms();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Phòng của tôi'),
      actions: [
        IconButton(
          tooltip: 'Về trang chủ',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/landlord/rooms/add'),
      icon: const Icon(Icons.add),
      label: const Text('Đăng phòng'),
    ),
    body: FutureBuilder<List<Room>>(
      future: _rooms,
      builder: (context, snapshot) => AsyncStateView<List<Room>>(
        snapshot: snapshot,
        errorPrefix: 'Không tải được phòng',
        onRetry: _reload,
        emptyMessage: 'Bạn chưa đăng phòng nào.',
        emptyIcon: Icons.add_home_outlined,
        emptyHint: 'Đăng một tin đăng kèm ảnh thật và giá rõ ràng sẽ dễ được liên hệ hơn.',
        emptyAction: FilledButton.icon(
          onPressed: () => context.push('/landlord/rooms/add'),
          icon: const Icon(Icons.add),
          label: const Text('Đăng phòng đầu tiên'),
        ),
        builder: (context, rooms) => RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              88,
            ),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final isFull = room.availableRooms == 0;
              return Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    PressableScale(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => context.push('/rooms/${room.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (room.image == null)
                              const _RoomPlaceholder()
                            else
                              AppNetworkImage(
                                room.image!,
                                width: 72,
                                height: 72,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    room.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.muted),
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: formatVnd(room.price),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontFeatures: AppTypography
                                                    .tabularFigures,
                                              ),
                                        ),
                                        TextSpan(
                                          text: '/tháng',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.muted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Xóa tin đăng',
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.muted,
                              ),
                              onSelected: (_) => _delete(room),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa phòng'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.md,
                        AppSpace.xs,
                        AppSpace.sm,
                        AppSpace.xs,
                      ),
                      child: Row(
                        children: [
                          StatusPill(
                            label: isFull
                                ? 'Hết phòng'
                                : 'Còn ${room.availableRooms}/${room.totalRooms} phòng',
                            background: isFull
                                ? AppColors.failureSoft
                                : AppColors.successSoft,
                            foreground: isFull
                                ? AppColors.failure
                                : AppColors.success,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _setAvailability(room),
                            child: const Text('Phòng trống'),
                          ),
                          TextButton(
                            onPressed: () => context.push(
                              '/landlord/rooms/${room.id}/edit',
                              extra: room,
                            ),
                            child: const Text('Sửa'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Future<void> _setAvailability(Room room) async {
    final count = await showDialog<int>(
      context: context,
      builder: (context) => _AvailabilityDialog(room: room),
    );
    if (count == null) return;
    await _run(
      () => ref.read(roomRepositoryProvider).setAvailability(room.id, count),
    );
  }

  Future<void> _delete(Room room) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Xóa phòng?',
      body: 'Bạn có chắc muốn xóa "${room.title}" không?',
      confirmLabel: 'Xóa',
      danger: true,
    );
    if (!confirmed) return;
    await _run(() => ref.read(roomRepositoryProvider).delete(room.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật phòng: $error')),
        );
      }
    }
  }
}

class _RoomPlaceholder extends StatelessWidget {
  const _RoomPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: const Icon(
      Icons.home_work_outlined,
      color: AppColors.subtle,
      size: 28,
    ),
  );
}

class _AvailabilityDialog extends StatefulWidget {
  const _AvailabilityDialog({required this.room});

  final Room room;

  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  late final TextEditingController _controller;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.room.availableRooms}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _value {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0 || parsed > widget.room.totalRooms) {
      return null;
    }
    return parsed;
  }

  void _submit() {
    final value = _value;
    if (value == null) {
      setState(() => _showError = true);
      return;
    }
    context.pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Phòng còn trống'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tin đăng này có ${widget.room.totalRooms} phòng. Đặt 0 khi đã kín hết.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          decoration: InputDecoration(
            labelText: 'Số phòng còn trống',
            suffixText: 'phòng',
            errorText: _showError
                ? 'Chỉ nhập từ 0 đến ${widget.room.totalRooms}.'
                : null,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
      FilledButton(onPressed: _submit, child: const Text('Lưu')),
    ],
  );
}
