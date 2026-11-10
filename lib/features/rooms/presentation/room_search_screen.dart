import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/room_card.dart';
import '../domain/room.dart';

class RoomSearchScreen extends ConsumerStatefulWidget {
  const RoomSearchScreen({super.key});

  @override
  ConsumerState<RoomSearchScreen> createState() => _RoomSearchScreenState();
}

class _RoomSearchScreenState extends ConsumerState<RoomSearchScreen> {
  /// Gõ xong 350ms mới tìm, để gõ nhanh 10 ký tự chỉ tốn 1–2 request.
  static const _debounce = Duration(milliseconds: 350);

  final _query = TextEditingController();
  Timer? _typing;
  late Future<List<Room>> _rooms;
  Map<String, Object?> _filters = {};

  @override
  void initState() {
    super.initState();
    _rooms = ref.read(roomRepositoryProvider).search();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onTyping(String _) {
    _typing?.cancel();
    _typing = Timer(_debounce, _search);
  }

  void _search() {
    _typing?.cancel();
    if (!mounted) return;
    setState(() => _rooms = _fetch());
  }

  Future<List<Room>> _fetch() => ref.read(roomRepositoryProvider).search({
      if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
      ..._filters,
    });

  int get _filterCount =>
      _filters.keys.where((key) => key != 'sort').length;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tìm phòng trọ'),
      actions: [
        IconButton(
          tooltip: 'Lọc phòng',
          onPressed: _filtersDialog,
          icon: Badge(
            isLabelVisible: _filterCount > 0,
            label: Text('$_filterCount'),
            child: const Icon(Icons.tune),
          ),
        ),
      ],
    ),
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
                  onChanged: _onTyping,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Khu vực, địa chỉ...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('Tìm')),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Room>>(
            future: _rooms,
            builder: (context, snapshot) => AsyncStateView<List<Room>>(
              snapshot: snapshot,
              errorPrefix: 'Không tìm được phòng',
              onRetry: _search,
              emptyMessage: 'Không tìm thấy phòng phù hợp.',
              emptyIcon: Icons.search_off,
              builder: (context, rooms) => RefreshIndicator(
                onRefresh: () async {
                  _search();
                  // Lỗi đã hiện trong danh sách, không ném tiếp ra RefreshIndicator.
                  await _rooms.then((_) {}, onError: (Object _) {});
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) =>
                      RoomCard(room: rooms[index]),
                ),
              ),
            ),
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
