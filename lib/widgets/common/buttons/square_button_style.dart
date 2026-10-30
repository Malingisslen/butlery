// lib/widgets/common/buttons/square_button_style.dart
//
// The onboarding button: square corners and a taller box; the outlined one
// takes an ink edge. A disabled outlined
// button keeps the theme's disabled edge.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

ButtonStyle squareButtonStyle(ThemeData theme, {required bool filled}) {
  final themeSide = theme.outlinedButtonTheme.style?.side;
  return ButtonStyle(
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size(0, AppDimensions.buttonHeight),
    ),
    textStyle: WidgetStatePropertyAll(AppTextStyles.labelLarge),
    side: filled
        ? null
        : WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? themeSide?.resolve(states)
                : BorderSide(
                    color: theme.colorScheme.onSurface,
                    width: AppDimensions.borderWidthOutlinedEdge,
                  ),
          ),
  );
}
