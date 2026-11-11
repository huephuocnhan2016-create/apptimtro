import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../map/presentation/open_street_map_layers.dart';
import '../../../shared/app_toast.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/rating_stars.dart';
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
        ScaffoldMessenger.of(context)
            .snack('Không thể cập nhật yêu thích: ${apiErrorMessage(error)}');
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
      await ref
          .read(roomRepositoryProvider)
          .submitReview(room.id, rating: draft.rating, comment: draft.comment);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .snack('Không gửi được đánh giá: ${apiErrorMessage(error)}');
      }
    }
  }

  Future<void> _copyPhone(Room room) async {
    await Clipboard.setData(ClipboardData(text: room.landlordPhone!));
    if (mounted) {
      ScaffoldMessenger.of(context).snack('Đã sao chép số điện thoại');
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
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      children: [
        _Gallery(pictures: pictures),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      room.address,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  if (room.ratingCount > 0)
                    RatingBadge(
                      average: room.ratingAverage!,
                      count: room.ratingCount,
                    ),
                  if (room.status == 'DEPOSITED') ...[
                    if (room.ratingCount > 0)
                      const SizedBox(width: AppSpace.sm),
                    StatusPill(
                      label: 'Đang cọc',
                      background: theme.colorScheme.secondaryContainer,
                      foreground: theme.colorScheme.onSecondaryContainer,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Row(
            children: [
              _Fact(value: '${formatNumber(room.area)} m²', label: 'Diện tích'),
              _Fact(
                value: '${room.availableRooms}/${room.totalRooms}',
                label: 'Phòng trống',
              ),
              _Fact(
                value: room.deposit > 0 ? formatVnd(room.deposit) : 'Không cọc',
                label: 'Cọc',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        SectionCard(
          title: 'Tiện ích',
          child: room.amenities.isEmpty
              ? Text('Chưa cập nhật')
              : Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final amenity in room.amenities)
                      Chip(
                        label: Text(amenity),
                        backgroundColor: AppColors.brandSoft,
                        side: BorderSide.none,
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Chi phí',
          child: Column(
            children: [
              DetailRow(
                label: 'Giá thuê',
                value: '${formatVnd(room.price)}/tháng',
              ),
              DetailRow(
                label: 'Tiền điện',
                value: '${formatVnd(room.electricityPrice)}/kWh',
              ),
              DetailRow(label: 'Tiền nước', value: formatVnd(room.waterPrice)),
              DetailRow(
                label: 'Internet',
                value: room.internetPrice > 0
                    ? '${formatVnd(room.internetPrice)}/tháng'
                    : 'Miễn phí',
              ),
              DetailRow(label: 'Tiền cọc', value: formatVnd(room.deposit)),
            ],
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
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
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
                title: Text(
                  room.landlordName ?? 'Chưa cập nhật',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: const Text('Chủ trọ'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: room.landlordPhone == null
                    ? const Text('SĐT chủ trọ: Chưa cập nhật')
                    : SelectableText(room.landlordPhone!),
                trailing: room.landlordPhone == null
                    ? null
                    : IconButton(
                        tooltip: 'Sao chép số điện thoại',
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyPhone(room),
                      ),
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
                    style: theme.textTheme.bodySmall,
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
    final initial = review.author.trim().isEmpty
        ? ''
        : review.author.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.brandSoft,
                child: Text(
                  initial,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(review.author, style: theme.textTheme.titleSmall),
              ),
              Text(
                formatDateVn(review.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          RatingStars(rating: review.rating.toDouble(), size: 16),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(review.comment!),
          ],
        ],
      ),
    );
  }

  /// Thanh hành động cố định dưới đáy — vị trí chuẩn của nút chính trong app
  /// Android khi nội dung dài và phải cuộn. Giá nằm cạnh nút vì quyết định
  /// đặt cọc luôn gắn với giá, không phải đoán lại từ nội dung phía trên.
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
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.sm,
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatVnd(room.price),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  Text('mỗi tháng', style: theme.textTheme.bodySmall),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: _favorite ? 'Bỏ yêu thích' : 'Yêu thích',
                onPressed: () => _toggleFavorite(room),
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? theme.colorScheme.error : null,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: canDeposit ? () => _openPayment(room) : null,
                  child: Text(
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

/// Thư viện ảnh bìa: trượt ngang, số trang và chấm chỉ báo để người dùng biết
/// còn những ảnh nào chưa xem.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.pictures});

  final List<String> pictures;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pictures.isEmpty) {
      return const SizedBox(
        height: 180,
        child: ColoredBox(
          color: AppColors.neutralSoft,
          child: Center(
            child: Icon(
              Icons.home_work_outlined,
              size: 64,
              color: AppColors.subtle,
            ),
          ),
        ),
      );
    }
    final many = widget.pictures.length > 1;
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.pictures.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => AppNetworkImage(
              widget.pictures[index],
              width: double.infinity,
              height: 240,
            ),
          ),
          if (many)
            Positioned(
              right: AppSpace.md,
              top: AppSpace.md,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.scrim,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  child: Text(
                    '${_page + 1}/${widget.pictures.length}',
                    style: const TextStyle(
                      color: AppColors.onBrand,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (many)
            Positioned(
              bottom: AppSpace.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < widget.pictures.length; index++)
                    AnimatedContainer(
                      duration: AppMotion.enter,
                      curve: AppMotion.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: index == _page ? 18 : 6,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppColors.onBrand
                            : AppColors.onBrandMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Một con số quét nhanh cạnh tiêu đề phòng: giá trị to, nhãn nhỏ.
class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
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
                  _rating >= star
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 32,
                  color: AppColors.star,
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
