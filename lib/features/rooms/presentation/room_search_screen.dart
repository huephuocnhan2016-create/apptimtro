import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/app_toast.dart';
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

  void _clearFilter(String key) {
    setState(() => _filters = {..._filters}..remove(key));
    _search();
  }

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RoomFiltersSheet(initial: _filters),
    );
    if (filters == null || !mounted) return;

    final needsLocation =
        filters['radius'] != null || filters['sort'] == 'distance';
    Object? position;
    if (needsLocation) {
      try {
        position = await ref.read(locationServiceProvider).currentPosition();
      } catch (_) {
        // Không lấy được vị trí thì vẫn giữ các tiêu chí còn lại, chỉ bỏ riêng
        // phần phụ thuộc vị trí và báo một lần — trước đây cả sheet lọc bị vứt.
        position = null;
        if (mounted) {
          ScaffoldMessenger.of(context)
              .snack('Không lấy được vị trí nên bỏ lọc theo khoảng cách.');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _filters = {
        ...filters,
        if (position != null) 'latitude': (position as dynamic).latitude,
        if (position != null) 'longitude': (position as dynamic).longitude,
      };
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm phòng trọ'),
        actions: [
          IconButton(
            tooltip: 'Lọc phòng',
            onPressed: _openFilters,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onChanged: _onTyping,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _query,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Xóa từ khóa',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _query.clear();
                            _search();
                          },
                        ),
                ),
                hintText: 'Khu vực, địa chỉ, trường học...',
              ),
            ),
          ),
          _ActiveFiltersRow(
            filters: _filters,
            onClearOne: _clearFilter,
            onClearAll: () {
              setState(() => _filters = {});
              _search();
            },
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
                emptyHint: 'Thử bỏ bớt bộ lọc hoặc đổi từ khóa gần hơn.',
                emptyAction: _filterCount > 0
                    ? FilledButton.tonal(
                        onPressed: () {
                          setState(() => _filters = {});
                          _search();
                        },
                        child: const Text('Xóa toàn bộ bộ lọc'),
                      )
                    : null,
                builder: (context, rooms) => RefreshIndicator(
                  onRefresh: () async {
                    _search();
                    // Lỗi đã hiện trong danh sách, không ném tiếp ra RefreshIndicator.
                    await _rooms.then((_) {}, onError: (Object _) {});
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      AppSpace.sm,
                      AppSpace.lg,
                      AppSpace.xxxl,
                    ),
                    itemCount: rooms.length + 1,
                    itemBuilder: (context, index) => index == 0
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: Text(
                              '${rooms.length} phòng',
                              style: text.titleMedium,
                            ),
                          )
                        : RoomCard(room: rooms[index - 1]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng chip trạng thái: bộ lọc đang bật phải nhìn thấy ngay trên kết quả,
/// không giấu sau badge của nút lọc.
class _ActiveFiltersRow extends StatelessWidget {
  const _ActiveFiltersRow({
    required this.filters,
    required this.onClearOne,
    required this.onClearAll,
  });

  final Map<String, Object?> filters;
  final ValueChanged<String> onClearOne;
  final VoidCallback onClearAll;

  static const sortLabels = {
    'newest': 'Mới nhất',
    'price_asc': 'Giá thấp → cao',
    'price_desc': 'Giá cao → thấp',
    'distance': 'Gần nhất',
  };

  @override
  Widget build(BuildContext context) {
    final chips = <(String, String)>[
      for (final spec in _FilterSpec.all)
        if (filters[spec.key] != null && spec.shortLabel.isNotEmpty)
          (spec.key, '${spec.shortLabel}: ${filters[spec.key]}'),
      if (filters['amenities'] != null)
        ('amenities', '${filters['amenities']}'),
      if (sortLabels.containsKey(filters['sort']))
        ('sort', sortLabels[filters['sort']]!),
    ];
    if (chips.isEmpty) return const SizedBox(height: AppSpace.sm);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        children: [
          for (final (key, label) in chips)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: InputChip(
                label: Text(label),
                onPressed: () => onClearOne(key),
                onDeleted: () => onClearOne(key),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.close, size: 18),
            label: const Text('Xóa lọc'),
            onPressed: onClearAll,
          ),
        ],
      ),
    );
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

/// Sheet bộ lọc: chọn nhanh bằng chip cho những gì hay dùng, nhập số cho phần
/// còn lại, sắp xếp bằng chip thay vì dropdown — một lần chạm là thấy ngay.
class _RoomFiltersSheet extends StatefulWidget {
  const _RoomFiltersSheet({required this.initial});

  final Map<String, Object?> initial;

  @override
  State<_RoomFiltersSheet> createState() => _RoomFiltersSheetState();
}

class _RoomFiltersSheetState extends State<_RoomFiltersSheet> {
  late final Map<String, TextEditingController> _fields;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final spec in _FilterSpec.all)
        spec.key: TextEditingController(
          text: '${widget.initial[spec.key] ?? ''}',
        ),
    };
    _sort = (widget.initial['sort'] as String?) ?? 'newest';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _result() => {
    for (final spec in _FilterSpec.all)
      if (_fields[spec.key]!.text.trim().isNotEmpty)
        spec.key: _normalizeFilterNumber(_fields[spec.key]!.text),
    'sort': _sort,
  };

  int? _number(String key) => int.tryParse(_fields[key]!.text.trim());

  void _applyPricePreset(int? min, int? max) {
    _fields['minPrice']!.text = '${min ?? ''}';
    _fields['maxPrice']!.text = '${max ?? ''}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
        left: AppSpace.lg,
        right: AppSpace.lg,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bộ lọc phòng', style: text.headlineMedium),
            const SizedBox(height: AppSpace.xl),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Giá thuê', style: text.titleMedium),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        _PresetChip(
                          label: 'Dưới 2 triệu',
                          selected: _number('maxPrice') == 2000000,
                          onTap: () => _applyPricePreset(null, 2000000),
                        ),
                        _PresetChip(
                          label: '2 – 3 triệu',
                          selected:
                              _number('minPrice') == 2000000 &&
                              _number('maxPrice') == 3000000,
                          onTap: () => _applyPricePreset(2000000, 3000000),
                        ),
                        _PresetChip(
                          label: 'Trên 3 triệu',
                          selected: _number('minPrice') == 3000000,
                          onTap: () => _applyPricePreset(3000000, null),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    _PairRow(
                      left: _field('minPrice'),
                      right: _field('maxPrice'),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text('Diện tích (m²)', style: text.titleMedium),
                    const SizedBox(height: AppSpace.md),
                    _PairRow(left: _field('minArea'), right: _field('maxArea')),
                    const SizedBox(height: AppSpace.xl),
                    _field('availableRooms'),
                    _field('radius'),
                    _field('amenities'),
                    const SizedBox(height: AppSpace.xl),
                    Text('Sắp xếp', style: text.titleMedium),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final entry
                            in _ActiveFiltersRow.sortLabels.entries)
                          _PresetChip(
                            label: entry.value,
                            selected: _sort == entry.key,
                            onTap: () => setState(() => _sort = entry.key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, {'sort': _sort}),
                    child: const Text('Xóa lọc'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _result()),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String key) {
    final spec = _FilterSpec.byKey(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: TextField(
        controller: _fields[key],
        keyboardType: spec.input,
        decoration: InputDecoration(
          labelText: spec.label,
          helperText: spec.hint,
        ),
      ),
    );
  }
}

class _FilterSpec {
  const _FilterSpec(
    this.key,
    this.label,
    this.input, {
    this.hint,
    this.shortLabel = '',
  });

  final String key;
  final String label;
  final TextInputType input;
  final String? hint;

  /// Nhãn ngắn dùng cho chip trạng thái trên màn kết quả.
  final String shortLabel;

  static const all = [
    _FilterSpec(
      'minPrice',
      'Giá từ (đ)',
      TextInputType.number,
      shortLabel: 'Từ',
    ),
    _FilterSpec(
      'maxPrice',
      'Giá đến (đ)',
      TextInputType.number,
      shortLabel: 'Dưới',
    ),
    _FilterSpec(
      'minArea',
      'Từ (m²)',
      TextInputType.number,
      shortLabel: 'DT từ',
    ),
    _FilterSpec(
      'maxArea',
      'Đến (m²)',
      TextInputType.number,
      shortLabel: 'DT đến',
    ),
    _FilterSpec(
      'availableRooms',
      'Số phòng còn tối thiểu',
      TextInputType.number,
      shortLabel: 'Còn ≥',
    ),
    _FilterSpec(
      'radius',
      'Khoảng cách tối đa (km)',
      TextInputType.numberWithOptions(decimal: true),
      shortLabel: 'Trong',
    ),
    _FilterSpec(
      'amenities',
      'Tiện ích, cách nhau bằng dấu phẩy',
      TextInputType.text,
      hint: 'Ví dụ: Wifi, Máy giặt, Điều hòa, Nước nóng',
    ),
  ];

  static _FilterSpec byKey(String key) =>
      all.firstWhere((spec) => spec.key == key);
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _PairRow extends StatelessWidget {
  const _PairRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: AppSpace.md),
      Expanded(child: right),
    ],
  );
}
