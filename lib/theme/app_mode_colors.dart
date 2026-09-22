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

  /// semantic focusRing: #24382C light, #F5F4ED dark (tokens.json:155-160).
  /// Never saffron (Grafisk manual v6:209).
  static Color focusRing(Brightness brightness) =>
      _isDark(brightness) ? AppColorsDark.focusRing : AppColors.focusRing;

  /// semantic action.primary: saffron #CE7C1E in both modes
  /// (tokens.json:137-140). The view's single hero action, never text.
  static Color actionPrimary(Brightness brightness) => _isDark(brightness)
      ? AppColorsDark.actionPrimary
      : AppColors.actionPrimary;

  /// semantic action.primaryPressed: #9A5C14 in both modes
  /// (tokens.json:141-144).
  static Color actionPrimaryPressed(Brightness brightness) =>
      _isDark(brightness)
      ? AppColorsDark.actionPrimaryPressed
      : AppColors.actionPrimaryPressed;

  /// semantic text.onActionPrimary: #17251D in both modes (tokens.json:81-85).
  /// Only on actionPrimary.
  static Color onActionPrimary(Brightness brightness) => _isDark(brightness)
      ? AppColorsDark.onActionPrimary
      : AppColors.onActionPrimary;

  /// semantic text.onActionPrimaryPressed: paper #F5F4ED in both modes
  /// (tokens.json:86-91; beslutslogg B-14). Only on actionPrimaryPressed.
  static Color onActionPrimaryPressed(Brightness brightness) =>
      _isDark(brightness)
      ? AppColorsDark.onActionPrimaryPressed
      : AppColors.onActionPrimaryPressed;
}
