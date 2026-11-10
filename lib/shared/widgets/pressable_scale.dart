import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Nén nhẹ phần tử khi bấm (scale 0.97 trong 140ms) để giao diện hưởng ứng
/// người dùng, vẫn giữ gợn sóng Material. Tự tắt khi máy bật giảm animation.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedScale(
      scale: _down && !reduced ? widget.scale : 1,
      duration: AppMotion.press,
      curve: AppMotion.easeOut,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: widget.child,
      ),
    );
  }
}
