import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      );
}
