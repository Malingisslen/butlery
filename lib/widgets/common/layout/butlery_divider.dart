// lib/widgets/common/layout/butlery_divider.dart
//
// The hairline between two things on a page, and the hairline with a word in
// the middle ("eller"). Colour and weight come from the theme's divider, so a
// view never picks them.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class ButleryDivider extends StatelessWidget {
  const ButleryDivider({this.indent = 0, this.endIndent = 0, super.key})
    : vertical = false;

  /// A hairline between two controls side by side.
  const ButleryDivider.vertical({super.key})
    : vertical = true,
      indent = 0,
      endIndent = 0;

  /// Space before the line, to start it under a row's text and not its icon.
  final double indent;
  final double endIndent;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) return const VerticalDivider();
    return Divider(indent: indent, endIndent: endIndent);
  }
}

/// A hairline, a word, a hairline: "eller" between two ways to do the same
/// thing.
class ButleryLabelledDivider extends StatelessWidget {
  const ButleryLabelledDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: ButleryDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: ButleryDivider()),
      ],
    );
  }
}
