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
    if (mounted) setState(() => _room = _load());
  }

  /// Quay về từ màn thanh toán → đọc lại phòng, để nút "Đặt cọc" đổi thành
  /// "Bạn đã cọc" nếu vừa cọc xong.
  Future<void> _openPayment(Room room) async {
    await context.push('/payment', extra: room);
    _reload();
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

  Widget _details(BuildContext context, Room room) {
    final pictures = room.images.isNotEmpty
        ? room.images
        : room.image == null
        ? <String>[]
        : [room.image!];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (pictures.isNotEmpty)
          SizedBox(
            height: 250,
            child: PageView(
              children: pictures
                  .map(
                    (url) => AppNetworkImage(url, height: 250),
                  )
                  .toList(),
            ),
          )
        else
          const SizedBox(
            height: 180,
            child: Icon(Icons.home_work_outlined, size: 72),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(room.address),
              if (room.status == 'DEPOSITED') ...[
                const SizedBox(height: 8),
                Chip(
                  label: const Text('Đang cọc'),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${formatVnd(room.price)}/tháng',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              _InfoLine('Diện tích', '${room.area} m²'),
              _InfoLine(
                'Phòng còn trống',
                '${room.availableRooms}/${room.totalRooms}',
              ),
              _InfoLine('Tiền điện', '${room.electricityPrice} đ/kWh'),
              _InfoLine('Tiền nước', '${room.waterPrice} đ/tháng'),
              _InfoLine('Internet', '${room.internetPrice} đ/tháng'),
              _InfoLine('Tiền cọc', '${room.deposit} đ'),
              const SizedBox(height: 16),
              Text('Tiện ích', style: Theme.of(context).textTheme.titleMedium),
              Text(
                room.amenities.isEmpty
                    ? 'Chưa cập nhật'
                    : room.amenities.join(' · '),
              ),
              const SizedBox(height: 16),
              Text('Mô tả', style: Theme.of(context).textTheme.titleMedium),
              Text(
                room.description.isEmpty ? 'Chưa có mô tả.' : room.description,
              ),
              const SizedBox(height: 16),
              Text('Vị trí', style: Theme.of(context).textTheme.titleMedium),
              if (room.latitude != null && room.longitude != null)
                SizedBox(
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
                )
              else
                Text(room.address),
              const SizedBox(height: 12),
              Text(
                'Chủ trọ: ${room.landlordName ?? 'Chưa cập nhật'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (room.landlordAvatar != null)
                CircleAvatar(
                  child: ClipOval(
                    child: AppNetworkImage(
                      room.landlordAvatar!,
                      width: 40,
                      height: 40,
                      errorWidget: const Icon(Icons.person_outline),
                    ),
                  ),
                ),
              if (room.landlordPhone != null)
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        'SĐT: ${room.landlordPhone}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sao chép số điện thoại',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: room.landlordPhone!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép số điện thoại'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                )
              else
                Text(
                  'SĐT chủ trọ: Chưa cập nhật',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        if (_favorite) {
                          await ref
                              .read(roomRepositoryProvider)
                              .unfavorite(room.id);
                        } else {
                          await ref
                              .read(roomRepositoryProvider)
                              .favorite(room.id);
                        }
                        if (mounted) setState(() => _favorite = !_favorite);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Không thể cập nhật yêu thích: ${apiErrorMessage(error)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      _favorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(_favorite ? 'Đã yêu thích' : 'Yêu thích'),
                  ),
                  OutlinedButton.icon(
                    onPressed: room.hasDeposit || room.status == 'DEPOSITED'
                        ? null
                        : () => _openPayment(room),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      room.hasDeposit
                          ? 'Bạn đã cọc'
                          : room.status == 'DEPOSITED'
                          ? 'Hết chỗ cọc'
                          : 'Đặt cọc',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}
