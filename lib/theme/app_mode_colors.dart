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

  /// semantic text.secondary.onRaised: #5B6959 light, #A9B2A0 dark
  /// (tokens.json:184-187). Secondary text on surface.raised, where plain
  /// text.secondary (#627061 / #93A48D) fails 4.5:1 in both modes.
  static Color textSecondaryOnRaised(Brightness brightness) =>
      _isDark(brightness) ? AppColorsDark.textMedium : AppColors.textMedium;

  /// semantic text.body: #37453A light, #F5F4ED dark (tokens.json:58-60, delivered
  /// as the generated member textOnCream per tools/app-theme-map.json:97-100).
  /// Body text under a bold title, as in the conflict banner
  /// (Komponentark v1:757).
  static Color textBody(Brightness brightness) =>
      _isDark(brightness) ? AppColorsDark.textOnCream : AppColors.textOnCream;

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

  /// semantic text.warning: #8A5212 light, #DCA968 dark (tokens.json:92-95).
  /// Warning text and warning glyphs on paper, such as the offline banner's
  /// outline and wifi-off glyph (Komponentark v1:753, dark :571). Not
  /// warning (border.statusWarning, never text) and not onWarningContainer
  /// (text.accent.onRaised, a different token).
  static Color textWarning(Brightness brightness) =>
      _isDark(brightness) ? AppColorsDark.textWarning : AppColors.textWarning;

  /// semantic overlay.paperWash: rgba(245,244,237,0.40) (tokens.json:263),
  /// delivered as the generated member overlayWhite40. The drawn dark outline
  /// of a secondary control, --ram-kontroll-a (Skarmar v12 etapp 4
  /// import:28). Only meaningful in dark mode, where the outline is paper.
  static Color paperWash(Brightness brightness) => _isDark(brightness)
      ? AppColorsDark.overlayWhite40
      : AppColors.overlayWhite40;

  // On surface.ink. The ink surface is #24382C in both modes
  // (tokens.json:112-115), so what stands on it takes one value in both
  // modes, whatever the page's brightness.

  /// semantic text.secondary (dark) #93A48D, delivered as the generated dark
  /// member greenMuted ("Nav ovald"), in both modes. The unchosen tabs of
  /// the ink bar (Komponentark v1:663-666) and quiet text on an ink card
  /// (Skarmar v12 del 1 #hemrecept :137). 4.73:1 on #24382C.
  static Color textSecondaryOnInk() => AppColorsDark.greenMuted;

  /// palette.saffronLight #E09D50, the generated member textAccentOnInk, in
  /// both modes: the accent text on ink (Komponentark v1:747; Skarmar v12
  /// del 1 #hemrecept :134, the card's eyebrow). 5.43:1 on #24382C.
  static Color textAccentOnInk() => AppColors.textAccentOnInk;
}
