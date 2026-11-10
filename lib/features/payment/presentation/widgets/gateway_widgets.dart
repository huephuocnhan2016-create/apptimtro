import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Một hàng chọn cổng thanh toán — `ListTile` + radio như `RadioGroup` trong
/// Android. App không tự quyết cổng: chọn hàng chỉ nói đơn sẽ mở qua cổng nào.
class GatewayOption extends StatelessWidget {
  const GatewayOption({
    required this.value,
    required this.selected,
    required this.brand,
    required this.name,
    required this.detail,
    required this.onSelect,
    super.key,
  });

  final String value;
  final bool selected;
  final Color brand;
  final String name;
  final String detail;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => onSelect(value),
    selected: selected,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? brand : AppColors.subtle,
    ),
    title: Text(name),
    subtitle: Text(detail),
  );
}
