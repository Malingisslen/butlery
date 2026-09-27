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
import 'package:butlery/theme/app_specific_colors.dart';

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

/// The mode-aware colour set that replaces `context.butleryColors` and the
/// `ButleryColors` theme extension (butlery_colors_extension.dart:147-148,
/// "kompatibilitetsyta ... Pensioneras i paket 7"; NULAGE.md:71-74).
///
/// It carries only a [Brightness] and no colour values of its own
/// (tokens.json:522): every member picks the generated AppColors or
/// AppColorsDark member for that brightness, and the four decorative
/// category colours the app owns come from AppSpecificColors. It is not a
/// ThemeExtension, so there is no override path; a theme's brightness is the
/// only input.
///
/// The name avoids the classes the design-system generator emits
/// (ButleryColors, ButleryType, ButlerySpace, ButleryRadius, ButleryMotion,
/// ButleryTouch, ButleryTheme; tokens.json:519).
///
/// Codemod: `context.butleryColors` becomes `context.modeColors`, a
/// `ButleryColors` parameter becomes [ModeColors], and
/// `ButleryColors.light` / `.dark` become [ModeColors.light] / [ModeColors.dark].
/// Each member maps to the same generated member ButleryColors used; the
/// line numbers below refer to butlery_colors_extension.dart at 3d6e82ea5.
final class ModeColors {
  const ModeColors._(this.brightness);

  /// The set for [brightness].
  factory ModeColors.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Light mode.
  static const light = ModeColors._(Brightness.light);

  /// Dark mode.
  static const dark = ModeColors._(Brightness.dark);

  /// The mode this set reads.
  final Brightness brightness;

  bool get _isDark => brightness == Brightness.dark;

  /// AppColors.chatBubbleOutgoing light, AppColorsDark.chatBubbleOutgoing dark (ButleryColors.light
  /// :150, .dark :198).
  Color get chatBubbleOutgoing =>
      _isDark ? AppColorsDark.chatBubbleOutgoing : AppColors.chatBubbleOutgoing;

  /// AppColors.chatBubbleIncoming light, AppColorsDark.chatBubbleIncoming dark (ButleryColors.light
  /// :151, .dark :199).
  Color get chatBubbleIncoming =>
      _isDark ? AppColorsDark.chatBubbleIncoming : AppColors.chatBubbleIncoming;

  /// AppColors.chatTextOutgoing light, AppColorsDark.chatTextOutgoing dark (ButleryColors.light
  /// :152, .dark :200).
  Color get chatTextOutgoing =>
      _isDark ? AppColorsDark.chatTextOutgoing : AppColors.chatTextOutgoing;

  /// AppColors.chatTextIncoming light, AppColorsDark.chatTextIncoming dark (ButleryColors.light
  /// :153, .dark :201).
  Color get chatTextIncoming =>
      _isDark ? AppColorsDark.chatTextIncoming : AppColors.chatTextIncoming;

  /// AppColors.success light, AppColorsDark.success dark (ButleryColors.light
  /// :154, .dark :202).
  Color get success => _isDark ? AppColorsDark.success : AppColors.success;

  /// AppColors.onSuccess light, AppColorsDark.onSuccess dark (ButleryColors.light
  /// :155, .dark :203).
  Color get onSuccess =>
      _isDark ? AppColorsDark.onSuccess : AppColors.onSuccess;

  /// AppColors.successContainer light, AppColorsDark.successContainer dark (ButleryColors.light
  /// :156, .dark :204).
  Color get successContainer =>
      _isDark ? AppColorsDark.successContainer : AppColors.successContainer;

  /// AppColors.onSuccessContainer light, AppColorsDark.onSuccessContainer dark (ButleryColors.light
  /// :157, .dark :205).
  Color get onSuccessContainer =>
      _isDark ? AppColorsDark.onSuccessContainer : AppColors.onSuccessContainer;

  /// AppColors.warning light, AppColorsDark.warning dark (ButleryColors.light
  /// :158, .dark :206).
  Color get warning => _isDark ? AppColorsDark.warning : AppColors.warning;

  /// AppColors.onWarning light, AppColorsDark.onWarning dark (ButleryColors.light
  /// :159, .dark :207).
  Color get onWarning =>
      _isDark ? AppColorsDark.onWarning : AppColors.onWarning;

  /// AppColors.warningContainer light, AppColorsDark.warningContainer dark (ButleryColors.light
  /// :160, .dark :208).
  Color get warningContainer =>
      _isDark ? AppColorsDark.warningContainer : AppColors.warningContainer;

  /// AppColors.onWarningContainer light, AppColorsDark.onWarningContainer dark (ButleryColors.light
  /// :161, .dark :209).
  Color get onWarningContainer =>
      _isDark ? AppColorsDark.onWarningContainer : AppColors.onWarningContainer;

  /// AppColors.info light, AppColorsDark.info dark (ButleryColors.light
  /// :162, .dark :210).
  Color get info => _isDark ? AppColorsDark.info : AppColors.info;

  /// AppColors.onInfo light, AppColorsDark.onInfo dark (ButleryColors.light
  /// :163, .dark :211).
  Color get onInfo => _isDark ? AppColorsDark.onInfo : AppColors.onInfo;

  /// AppColors.infoContainer light, AppColorsDark.infoContainer dark (ButleryColors.light
  /// :164, .dark :212).
  Color get infoContainer =>
      _isDark ? AppColorsDark.infoContainer : AppColors.infoContainer;

  /// AppColors.onInfoContainer light, AppColorsDark.onInfoContainer dark (ButleryColors.light
  /// :165, .dark :213).
  Color get onInfoContainer =>
      _isDark ? AppColorsDark.onInfoContainer : AppColors.onInfoContainer;

  /// AppColors.neutralMedium in both modes (ButleryColors.light :166,
  /// .dark :214).
  Color get neutral => AppColors.neutralMedium;

  /// AppColors.starGold in both modes (ButleryColors.light :167,
  /// .dark :215).
  Color get starGold => AppColors.starGold;

  /// AppColors.recipeCardLeftBorder light, AppColorsDark.recipeCardLeftBorder dark (ButleryColors.light
  /// :168, .dark :216).
  Color get recipeCardLeftBorder => _isDark
      ? AppColorsDark.recipeCardLeftBorder
      : AppColors.recipeCardLeftBorder;

  /// AppColors.recipeCardBottomBorder light, AppColorsDark.recipeCardBottomBorder dark (ButleryColors.light
  /// :169, .dark :217).
  Color get recipeCardBottomBorder => _isDark
      ? AppColorsDark.recipeCardBottomBorder
      : AppColors.recipeCardBottomBorder;

  /// AppColors.navSelectedIndicator in both modes (ButleryColors.light :170,
  /// .dark :218).
  Color get navAccent => AppColors.navSelectedIndicator;

  /// AppColors.greenMuted light, AppColorsDark.greenMuted dark (ButleryColors.light
  /// :171, .dark :219).
  Color get iconMuted =>
      _isDark ? AppColorsDark.greenMuted : AppColors.greenMuted;

  /// AppColors.greenPale light, AppColorsDark.greenPale dark (ButleryColors.light
  /// :172, .dark :220).
  Color get heroPaleGreen =>
      _isDark ? AppColorsDark.greenPale : AppColors.greenPale;

  /// AppColors.categoryMeatFish in both modes (ButleryColors.light :173,
  /// .dark :221).
  Color get categoryMeatFish => AppColors.categoryMeatFish;

  /// AppColors.categoryDairy in both modes (ButleryColors.light :174,
  /// .dark :222).
  Color get categoryDairy => AppColors.categoryDairy;

  /// AppColors.categoryVegetables in both modes (ButleryColors.light :175,
  /// .dark :223).
  Color get categoryVegetables => AppColors.categoryVegetables;

  /// AppColors.categoryFruit in both modes (ButleryColors.light :176,
  /// .dark :224).
  Color get categoryFruit => AppColors.categoryFruit;

  /// AppColors.categoryBreadGrains in both modes (ButleryColors.light :177,
  /// .dark :225).
  Color get categoryBreadGrains => AppColors.categoryBreadGrains;

  /// AppColors.categoryFrozen in both modes (ButleryColors.light :178,
  /// .dark :226).
  Color get categoryFrozen => AppColors.categoryFrozen;

  /// AppColors.categoryDryGoods in both modes (ButleryColors.light :179,
  /// .dark :227).
  Color get categoryDryGoods => AppColors.categoryDryGoods;

  /// AppColors.categoryOther in both modes (ButleryColors.light :180,
  /// .dark :228).
  Color get categoryOther => AppColors.categoryOther;

  /// AppSpecificColors.categoryDrinks light, AppSpecificColors.categoryDrinksDark dark (ButleryColors.light
  /// :181, .dark :229).
  Color get categoryDrinks => _isDark
      ? AppSpecificColors.categoryDrinksDark
      : AppSpecificColors.categoryDrinks;

  /// AppSpecificColors.categoryCleaning light, AppSpecificColors.categoryCleaningDark dark (ButleryColors.light
  /// :182, .dark :230).
  Color get categoryCleaning => _isDark
      ? AppSpecificColors.categoryCleaningDark
      : AppSpecificColors.categoryCleaning;

  /// AppSpecificColors.categorySnacks light, AppSpecificColors.categorySnacksDark dark (ButleryColors.light
  /// :183, .dark :231).
  Color get categorySnacks => _isDark
      ? AppSpecificColors.categorySnacksDark
      : AppSpecificColors.categorySnacks;

  /// AppSpecificColors.categoryCanned light, AppSpecificColors.categoryCannedDark dark (ButleryColors.light
  /// :184, .dark :232).
  Color get categoryCanned => _isDark
      ? AppSpecificColors.categoryCannedDark
      : AppSpecificColors.categoryCanned;

  /// AppColors.sharedRecipeText light, AppColorsDark.sharedRecipeText dark (ButleryColors.light
  /// :185, .dark :233).
  Color get sharedRecipeText =>
      _isDark ? AppColorsDark.sharedRecipeText : AppColors.sharedRecipeText;

  /// AppColors.sharedRecipeIcon in both modes (ButleryColors.light :186,
  /// .dark :234).
  Color get sharedRecipeIcon => AppColors.sharedRecipeIcon;

  /// AppColors.sharedRecipeBackground light, AppColorsDark.sharedRecipeBackground dark (ButleryColors.light
  /// :187, .dark :235).
  Color get sharedRecipeBackground => _isDark
      ? AppColorsDark.sharedRecipeBackground
      : AppColors.sharedRecipeBackground;

  /// AppColors.focusRing light, AppColorsDark.focusRing dark (ButleryColors.light
  /// :188, .dark :236).
  Color get focusRing =>
      _isDark ? AppColorsDark.focusRing : AppColors.focusRing;

  /// AppColors.progressTrack light, AppColorsDark.progressTrack dark (ButleryColors.light
  /// :189, .dark :237).
  Color get progressTrack =>
      _isDark ? AppColorsDark.progressTrack : AppColors.progressTrack;

  /// AppColors.progressIndicator light, AppColorsDark.progressIndicator dark (ButleryColors.light
  /// :190, .dark :238).
  Color get progressIndicator =>
      _isDark ? AppColorsDark.progressIndicator : AppColors.progressIndicator;

  /// AppColors.surfaceDisabled light, AppColorsDark.surfaceDisabled dark (ButleryColors.light
  /// :191, .dark :239).
  Color get surfaceDisabled =>
      _isDark ? AppColorsDark.surfaceDisabled : AppColors.surfaceDisabled;
}

/// `context.modeColors`: the [ModeColors] for the current theme's brightness.
extension ModeColorsAccess on BuildContext {
  /// Reads Theme.of(this).brightness, so dark mode never gets light values.
  ModeColors get modeColors => ModeColors.of(Theme.of(this).brightness);
}
