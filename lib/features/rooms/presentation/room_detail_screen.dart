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
import '../domain/room_review.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  late Future<Room> _room;
  late Future<List<RoomReview>> _reviews;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _room = _load();
  }

  Future<Room> _load() {
    // Đọc lại cùng lúc: gửi đánh giá xong thì điểm trung bình và danh sách
    // phải đổi ngay, nếu không người dùng tưởng lần gửi trước đã mất.
    _reviews = ref.read(roomRepositoryProvider).reviews(widget.roomId);
    return ref.read(roomRepositoryProvider).get(widget.roomId).then((room) {
      if (mounted) _favorite = room.isFavorite;
      return room;
    });
  }

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

  /// Chỉ sinh viên đã cọc mới có nút này; server vẫn kiểm tra lại lần nữa
  /// nên một phiên bản app cũ cũng không gửi được đánh giá trái điều kiện.
  Future<void> _writeReview(Room room) async {
    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => const _ReviewDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref.read(roomRepositoryProvider).submitReview(
        room.id,
        rating: draft.rating,
        comment: draft.comment,
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không gửi được đánh giá: ${apiErrorMessage(error)}',
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
        _reviewsSection(context, room),
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

  Widget _reviewsSection(BuildContext context, Room room) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Đánh giá',
      subtitle: room.ratingCount == 0
          ? 'Chưa có đánh giá'
          : '${formatNumber(room.ratingAverage!)} / 5 · ${room.ratingCount} lượt',
      trailing: room.canReview
          ? FilledButton.tonalIcon(
              onPressed: () => _writeReview(room),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Đánh giá'),
            )
          : null,
      child: FutureBuilder<List<RoomReview>>(
        future: _reviews,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Không tải được đánh giá: ${apiErrorMessage(snapshot.error!)}',
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final reviews = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reviews.isEmpty)
                Text(
                  room.canReview
                      ? 'Chưa có đánh giá nào — bạn là người đầu tiên ở đây.'
                      : 'Chưa có đánh giá nào.',
                )
              else
                for (final review in reviews) _reviewRow(context, review),
              if (!room.canReview)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Chỉ sinh viên đã đặt cọc phòng này mới bình luận và đánh giá được.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _reviewRow(BuildContext context, RoomReview review) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.author, style: theme.textTheme.titleSmall),
              ),
              Text(
                formatDateVn(review.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _Stars(value: review.rating.toDouble()),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!),
          ],
        ],
      ),
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

/// Hàng sao đọc được từ điểm trung bình: 4,5 làm tròn nửa ngôi giữa.
class _Stars extends StatelessWidget {
  const _Stars({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final score = value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            score >= star
                ? Icons.star
                : score >= star - 0.5
                ? Icons.star_half
                : Icons.star_border,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft(this.rating, this.comment);

  final int rating;
  final String? comment;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đánh giá phòng'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => setState(() => _rating = star),
                tooltip: '$star sao',
                icon: Icon(
                  _rating >= star ? Icons.star : Icons.star_border,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        TextField(
          controller: _comment,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Bình luận của bạn',
            hintText: 'Ví dụ: phòng sạch, chủ trọ trả lời nhanh',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _rating == 0
            ? null
            : () => Navigator.pop(
                context,
                _ReviewDraft(_rating, _comment.text.trim()),
              ),
        child: const Text('Gửi đánh giá'),
      ),
    ],
  );
}
