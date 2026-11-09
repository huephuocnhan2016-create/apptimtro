import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../domain/room.dart';

class RoomSearchScreen extends ConsumerStatefulWidget {
  const RoomSearchScreen({super.key});

  @override
  ConsumerState<RoomSearchScreen> createState() => _RoomSearchScreenState();
}

class _RoomSearchScreenState extends ConsumerState<RoomSearchScreen> {
  final _query = TextEditingController();
  late Future<List<Room>> _rooms;
  Map<String, Object?> _filters = {};

  @override
  void initState() {
    super.initState();
    _rooms = ref.read(roomRepositoryProvider).search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() => setState(() {
    _rooms = ref.read(roomRepositoryProvider).search({
      if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
      ..._filters,
    });
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tìm phòng trọ')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Khu vực, địa chỉ...',
                  ),
                ),
              ),
              IconButton(
                onPressed: _filtersDialog,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Room>>(
            future: _rooms,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Không tìm được phòng: ${apiErrorMessage(snapshot.error!)}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('Không tìm thấy phòng phù hợp.'),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) =>
                    RoomListTile(room: snapshot.data![index]),
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _filtersDialog() async {
    final minPrice = TextEditingController(
      text: '${_filters['minPrice'] ?? ''}',
    );
    final maxPrice = TextEditingController(
      text: '${_filters['maxPrice'] ?? ''}',
    );
    final minArea = TextEditingController(text: '${_filters['minArea'] ?? ''}');
    final maxArea = TextEditingController(text: '${_filters['maxArea'] ?? ''}');
    final rooms = TextEditingController(
      text: '${_filters['availableRooms'] ?? ''}',
    );
    final radius = TextEditingController(text: '${_filters['radius'] ?? ''}');
    final amenities = TextEditingController(
      text: '${_filters['amenities'] ?? ''}',
    );
    final sort = (_filters['sort'] as String?) ?? 'newest';
    var selectedSort = sort;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lọc phòng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterField(minPrice, 'Giá từ'),
                _filterField(maxPrice, 'Giá đến'),
                _filterField(minArea, 'Diện tích từ'),
                _filterField(maxArea, 'Diện tích đến'),
                _filterField(rooms, 'Số phòng còn tối thiểu'),
                _filterField(radius, 'Khoảng cách tối đa (km)'),
                _filterField(amenities, 'Tiện ích, cách nhau bằng dấu phẩy'),
                DropdownButtonFormField<String>(
                  initialValue: selectedSort,
                  decoration: const InputDecoration(labelText: 'Sắp xếp'),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
                    DropdownMenuItem(
                      value: 'price_asc',
                      child: Text('Giá tăng dần'),
                    ),
                    DropdownMenuItem(
                      value: 'price_desc',
                      child: Text('Giá giảm dần'),
                    ),
                    DropdownMenuItem(
                      value: 'distance',
                      child: Text('Gần nhất'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedSort = value ?? 'newest'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => context.pop(true),
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
    if (apply == true && mounted) {
      try {
        final needsLocation =
            radius.text.isNotEmpty || selectedSort == 'distance';
        final location = needsLocation
            ? await ref.read(locationServiceProvider).currentPosition()
            : null;
        if (!mounted) return;
        setState(() {
          _filters = {
            if (minPrice.text.isNotEmpty) 'minPrice': minPrice.text,
            if (maxPrice.text.isNotEmpty) 'maxPrice': maxPrice.text,
            if (minArea.text.isNotEmpty) 'minArea': minArea.text,
            if (maxArea.text.isNotEmpty) 'maxArea': maxArea.text,
            if (rooms.text.isNotEmpty) 'availableRooms': rooms.text,
            if (amenities.text.isNotEmpty) 'amenities': amenities.text,
            if (radius.text.isNotEmpty) 'radius': radius.text,
            if (location != null) 'latitude': location.latitude,
            if (location != null) 'longitude': location.longitude,
            'sort': selectedSort,
          };
        });
        _search();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể áp dụng bộ lọc: $error')),
          );
        }
      }
    }
    minPrice.dispose();
    maxPrice.dispose();
    minArea.dispose();
    maxArea.dispose();
    rooms.dispose();
    radius.dispose();
    amenities.dispose();
  }

  Widget _filterField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class RoomListTile extends StatelessWidget {
  const RoomListTile({required this.room, this.onChat, super.key});

  final Room room;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/rooms/${room.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 100,
            child: room.image == null
                ? const Icon(Icons.home_work_outlined)
                : Image.network(
                    room.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    room.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${room.price.toStringAsFixed(0)} đ/tháng'),
                  Text(
                    room.status == 'DEPOSITED'
                        ? 'Đang cọc'
                        : 'Còn ${room.availableRooms} phòng',
                  ),
                ],
              ),
            ),
          ),
          if (onChat != null)
            IconButton(
              tooltip: 'Nhắn tin với chủ trọ',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onChat,
            ),
        ],
      ),
    ),
  );
}
