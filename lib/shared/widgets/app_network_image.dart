import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Ảnh mạng có sẵn: nền chờ khi đang tải, khung báo lỗi khi tải hỏng, và
/// giải mã ảnh đúng kích thước hiển thị (cacheWidth) để danh sách không bị giật.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Thay khung lỗi mặc định (ví dụ avatar chữ cái cho ảnh đại diện).
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final w = width;
    final cacheWidth = w != null && w.isFinite ? (w * dpr).round() : null;
    Widget image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : _ImageBox(width: width, height: height),
      errorBuilder: (_, _, _) =>
          errorWidget ?? _ImageBox(width: width, height: height, failed: true),
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({this.width, this.height, this.failed = false});

  final double? width;
  final double? height;
  final bool failed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: ColoredBox(
      color: AppColors.neutralSoft,
      child: !failed
          ? const SizedBox.expand()
          : LayoutBuilder(
              builder: (context, constraints) {
                final roomy =
                    constraints.maxHeight >= 72 && constraints.maxWidth >= 110;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.subtle,
                      ),
                      if (roomy) ...[
                        const SizedBox(height: AppSpace.xs),
                        const Text(
                          'Ảnh không tải được',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    ),
  );
}
