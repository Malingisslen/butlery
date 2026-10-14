// lib/widgets/common/list/butlery_radio_row.dart
//
// One choice in a group of radio choices, as a 48 dp row with the canonical
// focus ring. It reads its group from the nearest RadioGroup, so a view
// wraps the rows in one RadioGroup and never styles a RadioListTile itself.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/butlery_control_focus.dart';

class ButleryRadioRow<T> extends StatelessWidget {
  const ButleryRadioRow({
    required this.title,
    required this.value,
    this.subtitle,
    this.enabled = true,
    super.key,
  });

  final String title;
  final T value;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ButleryControlFocus(
      child: RadioListTile<T>(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        enabled: enabled,
      ),
    );
  }
}
