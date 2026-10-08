import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';

/// The typed text of a field that can be disabled: [base] (or the field's
/// default) in its own colour while [enabled], and in text.disabled while
/// not. Without it Flutter draws disabled input text as onSurface at 38 %
/// opacity, which is not a design token (BUT-2184).
///
/// A plain style, not a state-resolved one: the field also hands its style to
/// the decoration as the hint's base, unresolved, so a state-resolved style
/// would drop the base's size from the hint.
TextStyle fieldTextStyle(
  BuildContext context, {
  required bool enabled,
  TextStyle? base,
}) {
  final cs = Theme.of(context).colorScheme;
  return (base ?? const TextStyle()).copyWith(
    color: enabled
        ? (base?.color ?? cs.onSurface)
        : AppModeColors.textDisabled(cs.brightness),
  );
}
