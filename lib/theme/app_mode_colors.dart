/// Mode-aware reads of generated colour members that have no ColorScheme slot.
///
/// The generated delivery (app_colors.dart and app_colors_dark.dart) carries
/// every canonical token twice, once per mode, under the same member name.
/// A theme builder or widget that needs one of those members picks the
/// member for the current brightness here, in the same way PlateLine does,
/// so no call site hard-codes the light value into dark mode.
///
/// This file holds no colour values of its own.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';

/// Picks the light or dark generated member for a brightness.
abstract final class AppModeColors {
  static bool _isDark(Brightness brightness) => brightness == Brightness.dark;

  /// semantic surface.disabled: #A9B2A0 light, #4A5C50 dark
  /// (tokens.json:120-123).
  static Color surfaceDisabled(Brightness brightness) => _isDark(brightness)
      ? AppColorsDark.surfaceDisabled
      : AppColors.surfaceDisabled;

  /// semantic text.disabled.onRaised: #788477 light, #93A48D dark
  /// (tokens.json:198). The surface-safe disabled text.
  static Color textDisabled(Brightness brightness) =>
      _isDark(brightness) ? AppColorsDark.textDisabled : AppColors.textDisabled;
}
