import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({required this.label, required this.brand, super.key});

  /// The portal's own short mark, as the header shows it.
  final String label;
  final Color brand;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: brand,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    ),
  );
}

/// One row of the portal chooser. The app makes no gateway decision of its own:
/// picking a row only says which portal the order should be opened through.
class GatewayOption extends StatelessWidget {
  const GatewayOption({
    required this.value,
    required this.selected,
    required this.brand,
    required this.mark,
    required this.name,
    required this.detail,
    required this.onSelect,
    super.key,
  });

  final String value;
  final bool selected;
  final Color brand;
  final String mark;
  final String name;
  final String detail;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onSelect(value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandSoft : Colors.white,
        border: Border.all(
          color: selected ? brand : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? brand : AppColors.subtle,
            size: 22,
          ),
          const SizedBox(width: 12),
          BrandMark(label: mark, brand: brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HeroBadge extends StatelessWidget {
  const HeroBadge({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.scrim,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}
