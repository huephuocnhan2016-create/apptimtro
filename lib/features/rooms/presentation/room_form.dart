import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/presentation/open_street_map_layers.dart';
import '../../../shared/app_toast.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/section_card.dart';
import '../domain/room.dart';

/// "Wifi, , Điều hòa" → ["Wifi", "Điều hòa"]. Tiện ích lưu một chuỗi phân cách
/// dấu phẩy nên cả lúc đọc lẫn lúc lưu phải tách theo cùng một quy tắc.
List<String> _splitCsv(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

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
      'price': _controller(_plain(room?.price)),
      'area': _controller(_plain(room?.area)),
      'totalRooms': _controller(room?.totalRooms.toString()),
      'availableRooms': _controller(room?.availableRooms.toString()),
      'latitude': _controller(_plain(room?.latitude)),
      'longitude': _controller(_plain(room?.longitude)),
      'electricityPrice': _controller(
        _plain(room?.electricityPrice, empty: '0'),
      ),
      'waterPrice': _controller(_plain(room?.waterPrice, empty: '0')),
      'internetPrice': _controller(_plain(room?.internetPrice, empty: '0')),
      'deposit': _controller(_plain(room?.deposit, empty: '0')),
      'amenities': _controller(room?.amenities.join(', ')),
    };
    final latitude = room?.latitude;
    final longitude = room?.longitude;
    if (latitude != null && longitude != null) {
      _mapPosition = LatLng(latitude, longitude);
    }
    _fields['address']!.addListener(_onAddressChanged);
    // Ô tiến độ phòng trống vẽ lại ngay khi chủ trọ gõ số.
    for (final name in ['totalRooms', 'availableRooms']) {
      _fields[name]!.addListener(_onCountsChanged);
    }
  }

  void _onCountsChanged() {
    if (mounted) setState(() {});
  }

  TextEditingController _controller(String? text) =>
      TextEditingController(text: text ?? '');

  /// Số nguyên không giữ đuôi ".0" và không hiện chữ "null" trong ô nhập.
  String _plain(double? value, {String empty = ''}) {
    if (value == null) return empty;
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

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
  Widget build(BuildContext context) => Scaffold(
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          SectionCard(
            title: 'Thông tin phòng',
            subtitle: 'Sinh viên đọc phần này đầu tiên',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _text('title', 'Tên phòng', required: true),
                _text('description', 'Mô tả', maxLines: 4),
                _AmenityPicker(controller: _fields['amenities']!),
              ],
            ),
          ),
          SectionCard(
            title: 'Chi phí',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _number('price', 'Giá thuê (đ/tháng)', required: true),
                _twoColumns(
                  _number('area', 'Diện tích (m²)', required: true),
                  _number('deposit', 'Tiền cọc (đ)'),
                ),
                _twoColumns(
                  _number('electricityPrice', 'Tiền điện (đ/kWh)'),
                  _number('waterPrice', 'Tiền nước (đ/tháng)'),
                ),
                _number('internetPrice', 'Internet (đ/tháng)'),
              ],
            ),
          ),
          SectionCard(
            title: 'Quy mô',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _twoColumns(
                  _number(
                    'totalRooms',
                    'Tổng số phòng',
                    required: true,
                    integer: true,
                  ),
                  _number(
                    'availableRooms',
                    'Số phòng còn',
                    required: true,
                    integer: true,
                  ),
                ),
                _occupancyHint(),
              ],
            ),
          ),
          SectionCard(
            title: 'Vị trí',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _text(
                  'address',
                  'Địa chỉ',
                  required: true,
                  helperText:
                      'Không có GPS vẫn lưu được: máy chủ tự tìm tọa độ.',
                ),
                _locationPreview(),
                FilledButton.tonalIcon(
                  onPressed: _gettingCurrentLocation
                      ? null
                      : _useCurrentLocation,
                  icon: Icon(
                    _gettingCurrentLocation
                        ? Icons.hourglass_empty_rounded
                        : Icons.my_location,
                  ),
                  label: Text(
                    _gettingCurrentLocation
                        ? 'Đang lấy vị trí...'
                        : 'Dùng vị trí GPS hiện tại',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Chỉnh vị trí trên bản đồ'),
                ),
              ],
            ),
          ),
          _imageCard(),
        ],
      ),
    ),
    bottomNavigationBar: _saveBar(),
  );

  Widget _saveBar() => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: AppButton(
          label: widget.room == null ? 'Tạo phòng' : 'Lưu thay đổi',
          busy: _saving,
          onPressed: _save,
        ),
      ),
    ),
  );

  Widget _imageCard() {
    final existing = widget.room?.images ?? const <String>[];
    return SectionCard(
      title: 'Hình ảnh',
      subtitle: 'Tin đăng có ảnh thật dễ được liên hệ hơn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing.isNotEmpty) ...[
            Text(
              'Ảnh đang hiển thị (${existing.length})',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: existing.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, index) => AppNetworkImage(
                  existing[index],
                  width: 96,
                  height: 72,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
          ],
          OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _images.isEmpty
                  ? 'Chọn ảnh phòng'
                  : 'Chọn thêm ảnh (${_images.length} ảnh mới)',
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpace.sm,
              crossAxisSpacing: AppSpace.sm,
              children: [
                for (var i = 0; i < _images.length; i++)
                  _PickedImage(
                    path: _images[i].path,
                    onRemove: () => setState(() => _images.removeAt(i)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Ảnh mới sẽ được tải lên khi bạn lưu phòng.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _twoColumns(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: AppSpace.md),
      Expanded(child: right),
    ],
  );

  Widget _occupancyHint() {
    final total = int.tryParse(_fields['totalRooms']!.text.trim());
    final available = int.tryParse(_fields['availableRooms']!.text.trim());
    if (total == null || available == null || total == 0) {
      return const SizedBox(height: AppSpace.sm);
    }
    final shown = available.clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: shown / total,
                minHeight: 6,
                backgroundColor: AppColors.neutralSoft,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Text(
            'Còn $shown/$total phòng trống',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
  }

  Widget _text(
    String name,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? helperText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
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
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
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
                            Icons.location_pin,
                            color: AppColors.brand,
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
          const SizedBox(height: AppSpace.sm),
          if (_resolvingAddress)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpace.sm),
                Text('Đang tìm vị trí địa chỉ...'),
              ],
            )
          else if (_addressError != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warningIcon,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    _addressError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.warningInk),
                  ),
                ),
              ],
            )
          else if (position != null)
            Text(
              'Tọa độ: ${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}. '
              'Chạm vào bản đồ để chỉnh lại.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              'Địa chỉ đã nhập sẽ được lưu cùng tin đăng.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  void _setAddressError(String? message) {
    if (mounted) setState(() => _addressError = message);
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
      _setAddressError(error.message);
    } on PlatformException {
      _setAddressError(
        'Không lấy được vị trí. Hãy cấp quyền vị trí và bật GPS trên thiết bị.',
      );
    } on TimeoutException {
      _setAddressError(
        'Không nhận được tín hiệu GPS. Hãy thử lại hoặc chọn vị trí trên bản đồ.',
      );
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
        _addressLookupFailed();
        return;
      }
      _setMapPosition(
        LatLng(locations.first.latitude, locations.first.longitude),
      );
    } on PlatformException {
      if (!mounted || request != _geocodeRequest) return;
      _addressLookupFailed();
    } on MissingPluginException {
      if (!mounted || request != _geocodeRequest) return;
      _addressLookupFailed();
    }
  }

  void _addressLookupFailed() => setState(() {
    _resolvingAddress = false;
    _addressError =
        'Thiết bị chưa tìm được tọa độ. Máy chủ sẽ thử tìm lại khi lưu phòng.';
  });

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
    padding: const EdgeInsets.only(bottom: AppSpace.md),
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
        if (number != null &&
            ((name == 'latitude' && (number < -90 || number > 90)) ||
                (name == 'longitude' && (number < -180 || number > 180)))) {
          return 'Tọa độ ngoài phạm vi';
        }
        if (name == 'area' && number != null && number == 0) {
          return 'Diện tích phải lớn hơn 0';
        }
        if (name == 'availableRooms' && number != null) {
          final total = int.tryParse(_fields['totalRooms']!.text.trim());
          if (total != null && number > total) {
            return 'Không vượt tổng số phòng';
          }
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
        'amenities': _splitCsv(_fields['amenities']!.text),
      };
      final repository = ref.read(roomRepositoryProvider);
      final saved = widget.room == null
          ? await repository.create(data)
          : await repository.update(widget.room!.id, data);
      // Tải ảnh song song. Phòng đã lưu rồi, nên ảnh lỗi chỉ báo riêng chứ
      // không báo "Không thể lưu phòng".
      final uploads = await Future.wait(
        _images.map(
          (image) => repository
              .uploadImage(saved.id, image.path)
              .then((_) => true, onError: (Object _) => false),
        ),
      );
      final failedUploads = uploads.where((ok) => !ok).length;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final hasNoMapPin = saved.latitude == null || saved.longitude == null;
      context.go(widget.room == null ? '/home' : '/landlord/rooms');
      if (failedUploads > 0) {
        messenger.snack(
          'Đã lưu phòng nhưng $failedUploads/${_images.length} ảnh '
          'tải lên không thành công. Hãy sửa phòng để thêm lại ảnh.',
        );
      } else if (hasNoMapPin) {
        messenger.snack(
          'Đã lưu phòng nhưng chưa xác định được vị trí ghim. '
          'Hãy chỉnh sửa phòng và chọn vị trí trên bản đồ.',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .snack('Không thể lưu phòng: ${apiErrorMessage(error)}');
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

/// Chọn tiện ích bằng cách chạm. Giá trị vẫn lưu dưới dạng chuỗi phân cách dấu
/// phẩy như cũ nên phần lưu phòng không đổi.
class _AmenityPicker extends StatefulWidget {
  const _AmenityPicker({required this.controller});

  final TextEditingController controller;

  @override
  State<_AmenityPicker> createState() => _AmenityPickerState();
}

class _AmenityPickerState extends State<_AmenityPicker> {
  static const _presets = [
    'Wifi',
    'Điều hòa',
    'Nước nóng',
    'Máy giặt',
    'Chỗ để xe',
    'Giờ tự do',
    'Thang máy',
    'Khu nấu ăn',
    'Camera an ninh',
    'Ban công',
    'Nhà vệ sinh khép kín',
    'Gần trường đại học',
    'Gần khu công nghiệp',
  ];

  final _custom = TextEditingController();

  List<String> get _selected => _splitCsv(widget.controller.text);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    final values = _selected;
    if (!values.remove(value)) values.add(value);
    widget.controller.text = values.join(', ');
  }

  void _addCustom() {
    final value = _custom.text.trim();
    if (value.isEmpty) return;
    final values = _selected;
    if (!values.contains(value)) values.add(value);
    widget.controller.text = values.join(', ');
    _custom.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Controller tiện ích thuộc về form cha, nên phải nghe nó trực tiếp thay
    // vì addListener + setState thủ công.
    listenable: widget.controller,
    builder: (context, _) {
      final selected = _selected;
      final options = <String>[
        ..._presets,
        ...selected.where((value) => !_presets.contains(value)),
      ];
      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiện ích',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final option in options)
                  FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: (_) => _toggle(option),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _custom,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustom(),
              decoration: InputDecoration(
                labelText: 'Tiện ích khác',
                hintText: 'VD: ban công rộng',
                suffixIcon: IconButton(
                  tooltip: 'Thêm tiện ích',
                  icon: const Icon(Icons.add),
                  onPressed: _addCustom,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Ảnh vừa chọn trên máy, bấm để bỏ trước khi lưu.
class _PickedImage extends StatelessWidget {
  const _PickedImage({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 200,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: AppColors.surfaceAlt,
            child: Icon(Icons.broken_image_outlined, color: AppColors.subtle),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: IconButton(
          tooltip: 'Bỏ ảnh này',
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          color: AppColors.onBrand,
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.scrim),
          onPressed: onRemove,
        ),
      ),
    ],
  );
}
