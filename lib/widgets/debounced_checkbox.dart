import 'package:flutter/material.dart';

class DebouncedCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final Duration debounceDuration;

  const DebouncedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
    );
  }
}
