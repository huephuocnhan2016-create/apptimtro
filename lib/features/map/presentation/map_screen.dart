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
    final theme = Theme.of(context);
    final markers = _rooms
        .where((room) => room.latitude != null && room.longitude != null)
        .map(
          (room) => Marker(
            point: LatLng(room.latitude!, room.longitude!),
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: room.title,
              onPressed: () {
                setState(() => _selectedRoomId = room.id);
                _showRoom(room);
              },
              icon: Icon(
                room.id == _selectedRoomId ? Icons.push_pin : Icons.location_on,
                size: 42,
                color: room.id == _selectedRoomId
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
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
            icon: const Icon(Icons.tune),
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
              MarkerLayer(markers: markers),
              if (_currentPosition case final current?)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: current,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.mapCurrentLocation,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              openStreetMapAttribution(),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 20,
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
              left: 16,
              right: 72,
              bottom: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 20),
                      const SizedBox(width: 8),
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
              top: 12,
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
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                child: Padding(
                  padding: EdgeInsets.all(12),
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
            padding: const EdgeInsets.all(16),
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
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (room.image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppNetworkImage(
                    room.image!,
                    height: 150,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${formatVnd(room.price)}/tháng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Còn ${room.availableRooms} phòng',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              if (room.distance != null)
                Text(
                  'Cách bạn ${room.distance!.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
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
    body: FlutterMap(
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
                child: Icon(
                  Icons.location_on,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        openStreetMapAttribution(),
      ],
    ),
  );
}
