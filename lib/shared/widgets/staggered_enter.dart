import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cho các phần tử xuất hiện lần lượt (40ms một món) khi vào màn. Chỉ dùng cho
/// màn người dùng gặp không thường xuyên; danh sách cuộn hằng ngày để tĩnh.
class StaggeredEnter extends StatefulWidget {
  const StaggeredEnter({
    required this.index,
    required this.child,
    this.maxSteps = 5,
    super.key,
  });

  final int index;
  final Widget child;

  /// Món thứ n trở đi vào cùng lúc, để cuộn nhanh không phải chờ dãy dài.
  final int maxSteps;

  @override
  State<StaggeredEnter> createState() => _StaggeredEnterState();
}

class _StaggeredEnterState extends State<StaggeredEnter> {
  bool _shown = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _shown) {
      return;
    }
    // Đọc MediaQuery ở đây thay vì initState: initState chưa đăng ký được
    // phụ thuộc vào InheritedWidget.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _shown = true;
      return;
    }
    final step = widget.index > widget.maxSteps
        ? widget.maxSteps
        : widget.index;
    _timer = Timer(AppMotion.stagger * step, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: AppMotion.enter,
    curve: AppMotion.easeOut,
    child: AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: AppMotion.enter,
      curve: AppMotion.easeOut,
      child: widget.child,
    ),
  );
}
