import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../map/presentation/open_street_map_layers.dart';
import '../domain/room.dart';

class RoomForm extends ConsumerStatefulWidget {
  const RoomForm({this.room, super.key});

  final Room? room;

  @override
  ConsumerState<RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends ConsumerState<RoomForm> {
  static const _defaultMapPosition = LatLng(10.77, 106.66);

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final Map<String, TextEditingController> _fields;
  final MapController _mapController = MapController();
  Timer? _addressDebounce;
  LatLng? _mapPosition;
  String? _addressError;
  bool _resolvingAddress = false;
  bool _gettingCurrentLocation = false;
  int _geocodeRequest = 0;
  List<XFile> _images = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _fields = {
      'title': _controller(room?.title),
      'address': _controller(room?.address),
      'description': _controller(room?.description),
      'price': _controller(room?.price.toString()),
      'area': _controller(room?.area.toString()),
      'totalRooms': _controller(room?.totalRooms.toString()),
      'availableRooms': _controller(room?.availableRooms.toString()),
      'latitude': _controller(room?.latitude.toString()),
      'longitude': _controller(room?.longitude.toString()),
      'electricityPrice': _controller(room?.electricityPrice.toString() ?? '0'),
      'waterPrice': _controller(room?.waterPrice.toString() ?? '0'),
      'internetPrice': _controller(room?.internetPrice.toString() ?? '0'),
      'deposit': _controller(room?.deposit.toString() ?? '0'),
      'amenities': _controller(room?.amenities.join(', ')),
    };
    final latitude = room?.latitude;
    final longitude = room?.longitude;
    if (latitude != null && longitude != null) {
      _mapPosition = LatLng(latitude, longitude);
    }
    _fields['address']!.addListener(_onAddressChanged);
  }

  TextEditingController _controller(String? text) =>
      TextEditingController(text: text ?? '');

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _mapController.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _text('title', 'Tên phòng', required: true),
        _text(
          'address',
          'Địa chỉ',
          required: true,
          helperText: 'Nhập địa chỉ; nếu thiết bị không tìm được tọa độ, máy chủ sẽ thử tìm khi lưu.',
        ),
        _locationPreview(),
        OutlinedButton.icon(
          onPressed: _gettingCurrentLocation ? null : _useCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: Text(
            _gettingCurrentLocation
                ? 'Đang lấy vị trí...'
                : 'Dùng vị trí GPS hiện tại',
          ),
        ),
        _text('description', 'Mô tả', maxLines: 4),
        _number('price', 'Giá thuê (đ/tháng)', required: true),
        _number('area', 'Diện tích (m²)', required: true),
        _number('totalRooms', 'Tổng số phòng', required: true, integer: true),
        _number(
          'availableRooms',
          'Số phòng còn',
          required: true,
          integer: true,
        ),
        _number('electricityPrice', 'Tiền điện (đ/kWh)'),
        _number('waterPrice', 'Tiền nước (đ/tháng)'),
        _number('internetPrice', 'Internet (đ/tháng)'),
        _number('deposit', 'Tiền cọc (đ)'),
        OutlinedButton.icon(
          onPressed: _pickLocation,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Chỉnh vị trí trên bản đồ'),
        ),
        _text('amenities', 'Tiện ích (phân cách bằng dấu phẩy)'),
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _images.isEmpty
                ? 'Chọn ảnh phòng'
                : 'Đã chọn ${_images.length} ảnh',
          ),
        ),
        if (widget.room?.images.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Ảnh hiện tại: ${widget.room!.images.length}'),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CircularProgressIndicator()
              : Text(widget.room == null ? 'Tạo phòng' : 'Lưu thay đổi'),
        ),
      ],
    ),
  );

  Widget _text(
    String name,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? helperText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[name],
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập $label'
                : null
          : null,
    ),
  );

  Widget _locationPreview() {
    final position = _mapPosition;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 210,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: position ?? _defaultMapPosition,
                  initialZoom: position == null ? 5 : 16,
                  onTap: (_, point) => _setMapPosition(point),
                ),
                children: [
                  openStreetMapTileLayer(),
                  if (position case final selected?)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: selected,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  openStreetMapAttribution(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_resolvingAddress)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Đang tìm vị trí địa chỉ...'),
              ],
            )
          else if (_addressError != null)
            Text(
              _addressError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (position != null)
            Text(
              'Tọa độ: ${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}. '
              'Chạm vào bản đồ để chỉnh lại.',
            )
          else
            const Text('Địa chỉ đã nhập sẽ được lưu cùng tin đăng.'),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gettingCurrentLocation = true;
      _addressError = null;
    });
    try {
      final current = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      _setMapPosition(LatLng(current.latitude, current.longitude));
    } on StateError catch (error) {
      if (mounted) setState(() => _addressError = error.message);
    } on PlatformException {
      if (mounted) {
        setState(() {
          _addressError = 'Không lấy được vị trí. Hãy cấp quyền vị trí và bật GPS trên thiết bị.';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _addressError = 'Không nhận được tín hiệu GPS. Hãy thử lại hoặc chọn vị trí trên bản đồ.';
        });
      }
    } finally {
      if (mounted) setState(() => _gettingCurrentLocation = false);
    }
  }

  void _onAddressChanged() {
    _addressDebounce?.cancel();
    final request = ++_geocodeRequest;
    final address = _fields['address']!.text.trim();
    setState(() {
      _mapPosition = null;
      _fields['latitude']!.clear();
      _fields['longitude']!.clear();
      _addressError = null;
      _resolvingAddress = address.length >= 8;
    });
    if (address.length < 8) {
      _mapController.move(_defaultMapPosition, 5);
      return;
    }
    _addressDebounce = Timer(
      const Duration(milliseconds: 900),
      () => _resolveAddress(address, request),
    );
  }

  Future<void> _resolveAddress(String address, int request) async {
    final query =
        RegExp(r'việt nam|vietnam', caseSensitive: false).hasMatch(address)
        ? address
        : '$address, Việt Nam';
    try {
      final locations = await Geocoding().locationFromAddress(
        query,
        locale: const Locale('vi', 'VN'),
      );
      if (!mounted || request != _geocodeRequest) return;
      if (locations.isEmpty) {
        setState(() {
          _resolvingAddress = false;
          _addressError = 'Thiết bị chưa tìm được tọa độ. Máy chủ sẽ thử tìm lại khi lưu phòng.';
        });
        return;
      }
      _setMapPosition(
        LatLng(locations.first.latitude, locations.first.longitude),
      );
    } on PlatformException {
      if (!mounted || request != _geocodeRequest) return;
      setState(() {
        _resolvingAddress = false;
        _addressError = 'Thiết bị chưa tìm được tọa độ. Máy chủ sẽ thử tìm lại khi lưu phòng.';
      });
    } on MissingPluginException {
      if (!mounted || request != _geocodeRequest) return;
      setState(() {
        _resolvingAddress = false;
        _addressError = 'Thiết bị chưa tìm được tọa độ. Máy chủ sẽ thử tìm lại khi lưu phòng.';
      });
    }
  }

  void _setMapPosition(LatLng point) {
    _addressDebounce?.cancel();
    _geocodeRequest++;
    _fields['latitude']!.text = point.latitude.toStringAsFixed(6);
    _fields['longitude']!.text = point.longitude.toStringAsFixed(6);
    setState(() {
      _mapPosition = point;
      _resolvingAddress = false;
      _addressError = null;
    });
    _mapController.move(point, 16);
  }

  Widget _number(
    String name,
    String label, {
    bool required = false,
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        final number = integer ? int.tryParse(text) : double.tryParse(text);
        if (required && text.isEmpty) return 'Vui lòng nhập $label';
        if (text.isNotEmpty && number == null) return 'Giá trị không hợp lệ';
        if (number != null &&
            number < 0 &&
            name != 'latitude' &&
            name != 'longitude') {
          return 'Giá trị không được âm';
        }
        if ((name == 'latitude' && (number! < -90 || number > 90)) ||
            (name == 'longitude' && (number! < -180 || number > 180))) {
          return 'Tọa độ ngoài phạm vi';
        }
        if (name == 'area' && number != null && number == 0) {
          return 'Diện tích phải lớn hơn 0';
        }
        return null;
      },
    ),
  );

  Future<void> _pickLocation() async {
    final point = await context.push<LatLng>('/map-picker');
    if (point == null || !mounted) return;
    _setMapPosition(point);
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (mounted && images.isNotEmpty) setState(() => _images = images);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = int.parse(_fields['totalRooms']!.text);
    final available = int.parse(_fields['availableRooms']!.text);
    if (available > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số phòng còn không thể lớn hơn tổng số phòng.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, Object?>{
        for (final name in ['title', 'address', 'description'])
          name: _fields[name]!.text.trim(),
        for (final name in [
          'price',
          'area',
          'electricityPrice',
          'waterPrice',
          'internetPrice',
          'deposit',
        ])
          name: double.parse(_fields[name]!.text),
        'totalRooms': total,
        'availableRooms': available,
        if (_fields['latitude']!.text.isNotEmpty &&
            _fields['longitude']!.text.isNotEmpty) ...{
          'latitude': double.parse(_fields['latitude']!.text),
          'longitude': double.parse(_fields['longitude']!.text),
        } else if (widget.room != null) ...{
          'latitude': null,
          'longitude': null,
        },
        'amenities': _fields['amenities']!.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      };
      final repository = ref.read(roomRepositoryProvider);
      final saved = widget.room == null
          ? await repository.create(data)
          : await repository.update(widget.room!.id, data);
      for (final image in _images) {
        await repository.uploadImage(saved.id, image.path);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final hasNoMapPin = saved.latitude == null || saved.longitude == null;
      context.go(widget.room == null ? '/home' : '/landlord/rooms');
      if (hasNoMapPin) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã lưu phòng nhưng chưa xác định được vị trí ghim. '
              'Hãy chỉnh sửa phòng và chọn vị trí trên bản đồ.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu phòng: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AddRoomScreen extends StatelessWidget {
  const AddRoomScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng phòng mới')),
    body: const RoomForm(),
  );
}

class EditRoomScreen extends StatelessWidget {
  const EditRoomScreen({required this.room, super.key});

  final Room room;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chỉnh sửa phòng')),
    body: RoomForm(room: room),
  );
}
