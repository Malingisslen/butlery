import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

/// The outlined button that is on or off: on is the raised surface behind a
/// 1.5 px text.primary border, off is the plain 1 px outline.
ButtonStyle toggleOutlinedButtonStyle(
  ColorScheme cs, {
  required bool selected,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: cs.onSurface,
    side: BorderSide(
      color: selected ? cs.onSurface : cs.outline,
      width: selected
          ? AppDimensions.borderWidthOutlinedEdge
          : AppDimensions.borderWidthStandard,
    ),
    backgroundColor: selected ? cs.surfaceContainerHighest : null,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.space4,
      vertical: AppDimensions.space4,
    ),
  );
}
