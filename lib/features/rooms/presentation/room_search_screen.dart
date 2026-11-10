import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    setState(() {
      _rooms = _fetch();
    });
  }

  Future<List<Room>> _fetch() => ref.read(roomRepositoryProvider).search({
    if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
    ..._filters,
  });

  /// Vị trí và kiểu sắp xếp chỉ là tham số kèm theo, không phải bộ lọc — tính
  /// chúng vào badge là người dùng thấy "3 bộ lọc" khi mới lọc mỗi giá.
  int get _filterCount => _filters.keys.where((key) {
    return key != 'sort' && key != 'latitude' && key != 'longitude';
  }).length;

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
                  itemBuilder: (context, index) => RoomCard(room: rooms[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _filtersDialog() async {
    final filters = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _RoomFiltersDialog(initial: _filters),
    );
    if (filters == null || !mounted) return;
    try {
      final needsLocation =
          filters['radius'] != null || filters['sort'] == 'distance';
      final location = needsLocation
          ? await ref.read(locationServiceProvider).currentPosition()
          : null;
      if (!mounted) return;
      setState(() {
        _filters = {
          ...filters,
          if (location != null) 'latitude': location.latitude,
          if (location != null) 'longitude': location.longitude,
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
}

/// Server chỉ nhận số, nên "2.000.000" phải về "2000000"; chuỗi lạ thì giữ
/// nguyên để server báo lỗi thay vì âm thầm bỏ bộ lọc.
String _normalizeFilterNumber(String raw) {
  final text = raw.trim();
  return RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(text)
      ? text.replaceAll(RegExp(r'[.,]'), '')
      : text;
}

class _FilterField {
  const _FilterField(this.key, this.label, this.input, {this.hint});

  final String key;
  final String label;
  final TextInputType input;
  final String? hint;
}

class _RoomFiltersDialog extends StatefulWidget {
  const _RoomFiltersDialog({required this.initial});

  final Map<String, Object?> initial;

  @override
  State<_RoomFiltersDialog> createState() => _RoomFiltersDialogState();
}

class _RoomFiltersDialogState extends State<_RoomFiltersDialog> {
  static const _specs = [
    _FilterField('minPrice', 'Giá từ', TextInputType.number),
    _FilterField('maxPrice', 'Giá đến', TextInputType.number),
    _FilterField('minArea', 'Diện tích từ', TextInputType.number),
    _FilterField('maxArea', 'Diện tích đến', TextInputType.number),
    _FilterField(
      'availableRooms',
      'Số phòng còn tối thiểu',
      TextInputType.number,
    ),
    _FilterField(
      'radius',
      'Khoảng cách tối đa (km)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _FilterField(
      'amenities',
      'Tiện ích, cách nhau bằng dấu phẩy',
      TextInputType.text,
      hint: 'Ví dụ: Wifi, Máy giặt, Điều hòa, Nước nóng',
    ),
  ];

  late final List<TextEditingController> _fields;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _fields = [
      for (final spec in _specs)
        TextEditingController(text: '${widget.initial[spec.key] ?? ''}'),
    ];
    _sort = (widget.initial['sort'] as String?) ?? 'newest';
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _result() => {
    for (var i = 0; i < _specs.length; i++)
      if (_fields[i].text.trim().isNotEmpty)
        _specs[i].key: _normalizeFilterNumber(_fields[i].text),
    'sort': _sort,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Lọc phòng'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _specs.length; i++) _field(_fields[i], _specs[i]),
          DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Sắp xếp'),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
              DropdownMenuItem(value: 'price_asc', child: Text('Giá tăng dần')),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text('Giá giảm dần'),
              ),
              DropdownMenuItem(value: 'distance', child: Text('Gần nhất')),
            ],
            onChanged: (value) => setState(() => _sort = value ?? 'newest'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, {'sort': _sort}),
        child: const Text('Xóa lọc'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _result()),
        child: const Text('Áp dụng'),
      ),
    ],
  );

  Widget _field(TextEditingController controller, _FilterField spec) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      keyboardType: spec.input,
      decoration: InputDecoration(labelText: spec.label, helperText: spec.hint),
    ),
  );
}
