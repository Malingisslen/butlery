// lib/widgets/styled/styled_input_borders.dart
//
// The edges of a StyledInput: resting, error and disabled, round or square.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/components/butlery_field_border.dart';

({
  InputBorder base,
  InputBorder resting,
  InputBorder error,
  InputBorder disabled,
})
styledInputBorders(
  BuildContext context, {
  required bool square,
  required bool showWarning,
}) {
  final cs = Theme.of(context).colorScheme;
  final radius = square
      ? BorderRadius.zero
      : BorderRadius.circular(AppDimensions.radiusControl);
  return (
    base: ButleryFieldBorder(
      borderRadius: radius,
      borderSide: const BorderSide(),
    ),
    resting: ButleryFieldBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: showWarning ? context.modeColors.warning : cs.outline,
        width: AppDimensions.borderWidthStandard,
      ),
    ),
    error: ButleryFieldBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.error,
        width: AppDimensions.borderWidthOutlinedEdge,
      ),
    ),
    disabled: ButleryFieldBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: AppModeColors.surfaceDisabled(cs.brightness),
        width: AppDimensions.borderWidthStandard,
      ),
    ),
  );
}
