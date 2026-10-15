import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../rooms/domain/room.dart';

class LandlordDashboardScreen extends StatelessWidget {
  const LandlordDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý phòng trọ')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const Text('Phòng của tôi'),
            subtitle: const Text('Quản lý tin đăng và phòng còn trống'),
            onTap: () => context.push('/landlord/rooms'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_home_outlined),
            title: const Text('Đăng phòng mới'),
            onTap: () => context.push('/landlord/rooms/add'),
          ),
        ),
      ],
    ),
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
        IconButton(
          onPressed: () => context.push('/landlord/rooms/add'),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<Room>>(
      future: _rooms,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Không tải được phòng: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Bạn chưa đăng phòng nào.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final room = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: room.image == null
                      ? const Icon(Icons.home_work_outlined)
                      : Image.network(
                          room.image!,
                          width: 56,
                          fit: BoxFit.cover,
                        ),
                  title: Text(room.title),
                  subtitle: Text(
                    '${room.price.toStringAsFixed(0)} đ · còn ${room.availableRooms}/${room.totalRooms} phòng',
                  ),
                  onTap: () => context.push('/rooms/${room.id}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _action(action, room),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(
                        value: 'availability',
                        child: Text('Cập nhật phòng trống'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Xóa phòng')),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  Future<void> _action(String action, Room room) async {
    final repository = ref.read(roomRepositoryProvider);
    try {
      if (action == 'edit') {
        await context.push('/landlord/rooms/${room.id}/edit', extra: room);
      } else if (action == 'availability') {
        final count = await showDialog<int>(
          context: context,
          builder: (context) => _AvailabilityDialog(room: room),
        );
        if (count != null) await repository.setAvailability(room.id, count);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa phòng?'),
            content: Text('Bạn có chắc muốn xóa "${room.title}" không?'),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (confirmed == true) await repository.delete(room.id);
      }
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

class _AvailabilityDialog extends StatefulWidget {
  const _AvailabilityDialog({required this.room});

  final Room room;

  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  late final TextEditingController _controller;

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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Phòng còn trống'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: 'Tối đa ${widget.room.totalRooms}'),
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Hủy')),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(_controller.text);
          if (value == null || value < 0 || value > widget.room.totalRooms) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Số phòng trống không hợp lệ.')),
            );
            return;
          }
          context.pop(value);
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
