// lib/widgets/common/buttons/button_row.dart
//
// Two or three buttons that share a line, an equal share of the width each.
// At large text they stack instead, one full-width button per line, in the
// same order.
library;

import 'package:flutter/widgets.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

class ButtonRow extends StatelessWidget {
  const ButtonRow({required this.children, super.key});

  /// Buttons built full-width (`isExpanded: true`, `expand: true`).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.space8,
        children: children,
      );
    }
    return Row(
      spacing: AppDimensions.space8,
      children: [for (final child in children) Expanded(child: child)],
    );
  }
}
