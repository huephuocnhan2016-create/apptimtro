import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../map/presentation/open_street_map_layers.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/section_card.dart';
import '../domain/room.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  late Future<Room> _room;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _room = _load();
  }

  Future<Room> _load() =>
      ref.read(roomRepositoryProvider).get(widget.roomId).then((room) {
        if (mounted) _favorite = room.isFavorite;
        return room;
      });

  void _reload() {
    if (mounted) {
      setState(() {
        _room = _load();
      });
    }
  }

  /// Quay về từ màn thanh toán → đọc lại phòng, để nút "Đặt cọc" đổi thành
  /// "Bạn đã cọc" nếu vừa cọc xong.
  Future<void> _openPayment(Room room) async {
    await context.push('/payment', extra: room);
    _reload();
  }

  Future<void> _toggleFavorite(Room room) async {
    try {
      if (_favorite) {
        await ref.read(roomRepositoryProvider).unfavorite(room.id);
      } else {
        await ref.read(roomRepositoryProvider).favorite(room.id);
      }
      if (mounted) setState(() => _favorite = !_favorite);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể cập nhật yêu thích: ${apiErrorMessage(error)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _copyPhone(Room room) async {
    await Clipboard.setData(ClipboardData(text: room.landlordPhone!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép số điện thoại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết phòng'),
      actions: [
        IconButton(
          tooltip: 'Về trang chủ',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
    ),
    body: FutureBuilder<Room>(
      future: _room,
      builder: (context, snapshot) => AsyncStateView<Room>(
        snapshot: snapshot,
        errorPrefix: 'Không tải được phòng',
        onRetry: _reload,
        builder: _details,
      ),
    ),
  );

  Widget _details(BuildContext context, Room room) => Column(
    children: [
      Expanded(child: _content(context, room)),
      _actionBar(context, room),
    ],
  );

  Widget _content(BuildContext context, Room room) {
    final theme = Theme.of(context);
    final pictures = room.images.isNotEmpty
        ? room.images
        : room.image == null
        ? <String>[]
        : [room.image!];
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (pictures.isNotEmpty)
          SizedBox(
            height: 230,
            child: PageView(
              children: pictures
                  .map((url) => AppNetworkImage(url, height: 230))
                  .toList(),
            ),
          )
        else
          const SizedBox(
            height: 160,
            child: Icon(Icons.home_work_outlined, size: 72),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                room.address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (room.status == 'DEPOSITED') ...[
                const SizedBox(height: 8),
                Chip(
                  label: const Text('Đang cọc'),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${formatVnd(room.price)}/tháng',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Thông tin phòng',
          child: Column(
            children: [
              DetailRow(
                label: 'Diện tích',
                value: '${formatNumber(room.area)} m²',
              ),
              DetailRow(
                label: 'Phòng còn trống',
                value: '${room.availableRooms}/${room.totalRooms}',
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Chi phí',
          child: Column(
            children: [
              DetailRow(
                label: 'Tiền điện',
                value: '${formatVnd(room.electricityPrice)}/kWh',
              ),
              DetailRow(label: 'Tiền nước', value: formatVnd(room.waterPrice)),
              DetailRow(
                label: 'Internet',
                value: formatVnd(room.internetPrice),
              ),
              DetailRow(label: 'Tiền cọc', value: formatVnd(room.deposit)),
            ],
          ),
        ),
        SectionCard(
          title: 'Tiện ích',
          child: Text(
            room.amenities.isEmpty
                ? 'Chưa cập nhật'
                : room.amenities.join(' · '),
          ),
        ),
        SectionCard(
          title: 'Mô tả',
          child: Text(
            room.description.isEmpty ? 'Chưa có mô tả.' : room.description,
          ),
        ),
        SectionCard(
          title: 'Vị trí',
          child: room.latitude != null && room.longitude != null
              ? SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(room.latitude!, room.longitude!),
                      initialZoom: 15,
                    ),
                    children: [
                      openStreetMapTileLayer(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(room.latitude!, room.longitude!),
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.location_on,
                              color: theme.colorScheme.error,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                      openStreetMapAttribution(),
                    ],
                  ),
                )
              : Text(room.address),
        ),
        SectionCard(
          title: 'Chủ trọ',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: room.landlordAvatar == null
                    ? const CircleAvatar(child: Icon(Icons.person_outline))
                    : CircleAvatar(
                        foregroundImage: NetworkImage(room.landlordAvatar!),
                      ),
                title: Text('Chủ trọ: ${room.landlordName ?? 'Chưa cập nhật'}'),
              ),
              if (room.landlordPhone != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: SelectableText('SĐT: ${room.landlordPhone}'),
                  trailing: IconButton(
                    tooltip: 'Sao chép số điện thoại',
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyPhone(room),
                  ),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('SĐT chủ trọ: Chưa cập nhật'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Thanh hành động cố định dưới đáy — vị trí chuẩn của nút chính trong app
  /// Android khi nội dung dài và phải cuộn.
  Widget _actionBar(BuildContext context, Room room) {
    final theme = Theme.of(context);
    final canDeposit = !room.hasDeposit && room.status != 'DEPOSITED';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _toggleFavorite(room),
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? theme.colorScheme.error : null,
                ),
                label: Text(_favorite ? 'Đã yêu thích' : 'Yêu thích'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canDeposit ? () => _openPayment(room) : null,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(
                    room.hasDeposit
                        ? 'Bạn đã cọc'
                        : room.status == 'DEPOSITED'
                        ? 'Hết chỗ cọc'
                        : 'Đặt cọc',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
