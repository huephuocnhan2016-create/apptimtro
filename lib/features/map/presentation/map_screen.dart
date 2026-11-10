import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_error_message.dart';
import '../../rooms/domain/room.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'open_street_map_layers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _fallback = LatLng(10.77, 106.66);
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  String? _currentAddress;
  List<Room> _rooms = [];
  String? _error;
  bool _loading = true;
  bool _areaNeedsSearch = false;
  bool _mapReady = false;
  String? _selectedRoomId;
  double _radiusKm = 30;
  Timer? _cameraDebounce;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  Future<void> _loadNearby() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.currentPosition();
      final center = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _currentPosition = center;
        _currentAddress = null;
      });
      if (_mapReady) _centerOnUser(center);
      final rooms = await ref
          .read(roomRepositoryProvider)
          .nearby(
            latitude: position.latitude,
            longitude: position.longitude,
            radius: _radiusKm,
          );
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
      unawaited(_resolveAddress(position.latitude, position.longitude));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _resolveAddress(double latitude, double longitude) async {
    final address = await ref
        .read(locationServiceProvider)
        .addressFrom(latitude, longitude);
    if (!mounted || address == null) return;
    setState(() => _currentAddress = address);
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _rooms
        .where((room) => room.latitude != null && room.longitude != null)
        .map(
          (room) => Marker(
            point: LatLng(room.latitude!, room.longitude!),
            width: 84,
            height: 36,
            child: Center(
              child: _PriceMarker(
                room: room,
                selected: room.id == _selectedRoomId,
                onTap: () {
                  setState(() => _selectedRoomId = room.id);
                  _showRoom(room);
                },
              ),
            ),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng trọ gần bạn'),
        actions: [
          IconButton(
            tooltip: 'Về trang chủ',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: 'Bán kính tìm kiếm',
            onPressed: _chooseRadius,
            icon: Badge(
              isLabelVisible: _radiusKm != 30,
              label: Text(_radiusKm.toStringAsFixed(0)),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallback,
              initialZoom: 12,
              onMapReady: () {
                _mapReady = true;
                final position = _currentPosition;
                if (position != null) _centerOnUser(position);
              },
              onPositionChanged: (camera, hasGesture) {
                if (!hasGesture) return;
                _cameraDebounce?.cancel();
                _cameraDebounce = Timer(const Duration(milliseconds: 700), () {
                  if (mounted) setState(() => _areaNeedsSearch = true);
                });
              },
            ),
            children: [
              openStreetMapTileLayer(),
              // Vị trí của bạn vẽ trước ghim phòng: hai điểm trùng nhau thì
              // nhãn giá vẫn nằm trên và vẫn bấm được.
              if (_currentPosition case final current?)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: current,
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.mapCurrentLocation,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
              openStreetMapAttribution(),
            ],
          ),
          Positioned(
            right: AppSpace.lg,
            bottom: AppSpace.xxl,
            child: FloatingActionButton.small(
              tooltip: 'Vị trí hiện tại',
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _loadNearby();
                    },
              child: const Icon(Icons.my_location),
            ),
          ),
          if (_currentPosition != null)
            Positioned(
              left: AppSpace.lg,
              right: 72,
              bottom: AppSpace.xxl,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 20),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          _currentAddress ?? 'Đang xác định địa chỉ...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_areaNeedsSearch && !_loading)
            Positioned(
              top: AppSpace.md,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _searchThisArea,
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm kiếm khu vực này'),
                ),
              ),
            ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            )
          else if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(AppSpace.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadNearby();
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_rooms.isEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(AppSpace.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Text(
                    'Không tìm thấy phòng trong bán kính ${_radiusKm.toStringAsFixed(0)} km.',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseRadius() async {
    var selected = _radiusKm;
    final result = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bán kính ${selected.toStringAsFixed(0)} km',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: selected,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${selected.toStringAsFixed(0)} km',
                  onChanged: (value) => setSheetState(() => selected = value),
                ),
                const SizedBox(height: AppSpace.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _radiusKm = result;
      _areaNeedsSearch = true;
    });
  }

  Future<void> _searchThisArea() async {
    setState(() {
      _loading = true;
      _error = null;
      _areaNeedsSearch = false;
    });
    try {
      final center = _mapController.camera.center;
      final rooms = await ref
          .read(roomRepositoryProvider)
          .nearby(
            latitude: center.latitude,
            longitude: center.longitude,
            radius: _radiusKm,
          );
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(error);
        _loading = false;
      });
    }
  }

  void _centerOnUser(LatLng position) {
    _mapController.move(position, 14);
  }

  void _showRoom(Room room) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            0,
            AppSpace.lg,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (room.image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: AppNetworkImage(
                    room.image!,
                    height: 160,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              Text(room.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                room.address,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Text(
                    formatVnd(room.price),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontFeatures: AppTypography.tabularFigures),
                  ),
                  Text('/tháng', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text('Còn ${room.availableRooms} phòng'),
                ],
              ),
              if (room.distance != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(
                    'Cách bạn ${room.distance!.toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/rooms/${room.id}');
                },
                child: const Text('Xem chi tiết'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giá rút gọn cho marker: "2,5 tr" vẫn đọc được khi nhiều ghim đè nhau.
String _shortPrice(double price) => price >= 1000000
    ? '${formatNumber(price / 1000000)} tr'
    : '${formatNumber(price / 1000)} k';

/// Ghim giá kiểu marketplace: con số ngay trên bản đồ thay vì một cây ghim
/// vô danh, người dùng so được giá mà chưa cần mở phòng.
class _PriceMarker extends StatelessWidget {
  const _PriceMarker({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final Room room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.brand : AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? AppColors.brand : AppColors.border,
        width: 1.5,
      ),
    ),
    elevation: 2,
    shadowColor: AppColors.shadow,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Text(
          _shortPrice(room.price),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: selected ? AppColors.onBrand : AppColors.ink),
        ),
      ),
    ),
  );
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _initial = LatLng(10.77, 106.66);
  final MapController _mapController = MapController();
  LatLng? _selected;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chọn vị trí phòng'),
      actions: [
        TextButton(
          onPressed: _selected == null ? null : () => context.pop(_selected),
          child: const Text('Chọn'),
        ),
      ],
    ),
    body: Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initial,
            initialZoom: 12,
            onTap: (_, point) => setState(() => _selected = point),
          ),
          children: [
            openStreetMapTileLayer(),
            if (_selected case final selected?)
              MarkerLayer(
                markers: [
                  Marker(
                    point: selected,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      size: 42,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            openStreetMapAttribution(),
          ],
        ),
        Positioned(
          top: AppSpace.md,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                child: Text(
                  _selected == null
                      ? 'Chạm vào bản đồ để đặt vị trí phòng'
                      : 'Đã chọn vị trí, bấm Chọn để lưu',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
