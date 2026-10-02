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
  /// (tokens.json). Secondary text on surface.raised.
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
  /// Warning text and warning glyphs on paper. Not
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

  /// semantic text.secondary (dark) #A9B2A0, delivered as the generated dark
  /// member greenMuted ("Nav ovald"), in both modes. The unchosen tabs of
  /// the ink bar (Komponentark v1:663-666) and quiet text on an ink card
  /// (Skarmar v12 del 1 #hemrecept :137).
  static Color textSecondaryOnInk() => AppColorsDark.greenMuted;

  /// palette.saffronLight #E09D50, the generated member textAccentOnInk, in
  /// both modes: the accent text on ink (Komponentark v1:747; Skarmar v12
  /// del 1 #hemrecept :134, the card's eyebrow). 5.43:1 on #24382C.
  static Color textAccentOnInk() => AppColors.textAccentOnInk;

  /// palette.inkRaised #2F4437 in both modes: a raised surface on ink, such as
  /// a row or card inside the outgoing chat bubble.
  static Color surfaceRaisedOnInk() => AppColors.surfaceDark;

  /// semantic border.onInk #3F5145 in both modes: the line between ink and
  /// inkRaised, and the fill of a progress bar on an inkRaised track in the
  /// outgoing chat bubble (B101).
  static Color borderOnInk() => AppColors.borderOnInk;

  /// semantic surface.base light #F5F4ED, in both modes: an opaque paper card
  /// that carries ink text over a photo scrim, so the text pair does not depend
  /// on the photo behind it (B102). The translucent overlayPaperCard stays for
  /// pills directly on a photo.
  static Color surfacePaperOnPhoto() => AppColors.cardWhite;
}

/// The mode-aware colour set for members that have no ColorScheme slot.
///
/// It replaced the retired compatibility theme extension in package 7
/// (NULAGE.md:71-74). It carries only a [Brightness] and no colour values of
/// its own (tokens.json:522): every member picks the generated AppColors or
/// AppColorsDark member for that brightness, and the four decorative
/// category colours the app owns come from AppSpecificColors. It is not a
/// ThemeExtension, so there is no override path; a theme's brightness is the
/// only input.
///
/// The name avoids the classes the design-system generator emits
/// (tokens.json:519).
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

  /// AppColors.chatBubbleOutgoing light, AppColorsDark.chatBubbleOutgoing dark.
  Color get chatBubbleOutgoing =>
      _isDark ? AppColorsDark.chatBubbleOutgoing : AppColors.chatBubbleOutgoing;

  /// AppColors.chatBubbleIncoming light, AppColorsDark.chatBubbleIncoming dark.
  Color get chatBubbleIncoming =>
      _isDark ? AppColorsDark.chatBubbleIncoming : AppColors.chatBubbleIncoming;

  /// AppColors.chatTextOutgoing light, AppColorsDark.chatTextOutgoing dark.
  Color get chatTextOutgoing =>
      _isDark ? AppColorsDark.chatTextOutgoing : AppColors.chatTextOutgoing;

  /// AppColors.chatTextIncoming light, AppColorsDark.chatTextIncoming dark.
  Color get chatTextIncoming =>
      _isDark ? AppColorsDark.chatTextIncoming : AppColors.chatTextIncoming;

  /// AppColors.success light, AppColorsDark.success dark.
  Color get success => _isDark ? AppColorsDark.success : AppColors.success;

  /// AppColors.onSuccess light, AppColorsDark.onSuccess dark.
  Color get onSuccess =>
      _isDark ? AppColorsDark.onSuccess : AppColors.onSuccess;

  /// AppColors.successContainer light, AppColorsDark.successContainer dark.
  Color get successContainer =>
      _isDark ? AppColorsDark.successContainer : AppColors.successContainer;

  /// AppColors.onSuccessContainer light, AppColorsDark.onSuccessContainer dark.
  Color get onSuccessContainer =>
      _isDark ? AppColorsDark.onSuccessContainer : AppColors.onSuccessContainer;

  /// AppColors.warning light, AppColorsDark.warning dark.
  Color get warning => _isDark ? AppColorsDark.warning : AppColors.warning;

  /// AppColors.onWarning light, AppColorsDark.onWarning dark.
  Color get onWarning =>
      _isDark ? AppColorsDark.onWarning : AppColors.onWarning;

  /// AppColors.warningContainer light, AppColorsDark.warningContainer dark.
  Color get warningContainer =>
      _isDark ? AppColorsDark.warningContainer : AppColors.warningContainer;

  /// AppColors.onWarningContainer light, AppColorsDark.onWarningContainer dark.
  Color get onWarningContainer =>
      _isDark ? AppColorsDark.onWarningContainer : AppColors.onWarningContainer;

  /// AppColors.info light, AppColorsDark.info dark.
  Color get info => _isDark ? AppColorsDark.info : AppColors.info;

  /// AppColors.onInfo light, AppColorsDark.onInfo dark.
  Color get onInfo => _isDark ? AppColorsDark.onInfo : AppColors.onInfo;

  /// AppColors.infoContainer light, AppColorsDark.infoContainer dark.
  Color get infoContainer =>
      _isDark ? AppColorsDark.infoContainer : AppColors.infoContainer;

  /// AppColors.onInfoContainer light, AppColorsDark.onInfoContainer dark.
  Color get onInfoContainer =>
      _isDark ? AppColorsDark.onInfoContainer : AppColors.onInfoContainer;

  /// AppColors.neutralMedium in both modes.
  Color get neutral => AppColors.neutralMedium;

  /// AppColors.starGold in both modes.
  Color get starGold => AppColors.starGold;

  /// AppColors.recipeCardLeftBorder light, AppColorsDark.recipeCardLeftBorder dark.
  Color get recipeCardLeftBorder => _isDark
      ? AppColorsDark.recipeCardLeftBorder
      : AppColors.recipeCardLeftBorder;

  /// AppColors.recipeCardBottomBorder light, AppColorsDark.recipeCardBottomBorder dark.
  Color get recipeCardBottomBorder => _isDark
      ? AppColorsDark.recipeCardBottomBorder
      : AppColors.recipeCardBottomBorder;

  /// AppColors.navSelectedIndicator in both modes.
  Color get navAccent => AppColors.navSelectedIndicator;

  /// AppColors.greenMuted light, AppColorsDark.greenMuted dark.
  Color get iconMuted =>
      _isDark ? AppColorsDark.greenMuted : AppColors.greenMuted;

  /// AppColors.greenPale light, AppColorsDark.greenPale dark.
  Color get heroPaleGreen =>
      _isDark ? AppColorsDark.greenPale : AppColors.greenPale;

  /// AppColors.categoryMeatFish in both modes.
  Color get categoryMeatFish => AppColors.categoryMeatFish;

  /// AppColors.categoryDairy in both modes.
  Color get categoryDairy => AppColors.categoryDairy;

  /// AppColors.categoryVegetables in both modes.
  Color get categoryVegetables => AppColors.categoryVegetables;

  /// AppColors.categoryFruit in both modes.
  Color get categoryFruit => AppColors.categoryFruit;

  /// AppColors.categoryBreadGrains in both modes.
  Color get categoryBreadGrains => AppColors.categoryBreadGrains;

  /// AppColors.categoryFrozen in both modes.
  Color get categoryFrozen => AppColors.categoryFrozen;

  /// AppColors.categoryDryGoods in both modes.
  Color get categoryDryGoods => AppColors.categoryDryGoods;

  /// AppColors.categoryOther in both modes.
  Color get categoryOther => AppColors.categoryOther;

  /// AppSpecificColors.categoryDrinks light, AppSpecificColors.categoryDrinksDark dark.
  Color get categoryDrinks => _isDark
      ? AppSpecificColors.categoryDrinksDark
      : AppSpecificColors.categoryDrinks;

  /// AppSpecificColors.categoryCleaning light, AppSpecificColors.categoryCleaningDark dark.
  Color get categoryCleaning => _isDark
      ? AppSpecificColors.categoryCleaningDark
      : AppSpecificColors.categoryCleaning;

  /// AppSpecificColors.categorySnacks light, AppSpecificColors.categorySnacksDark dark.
  Color get categorySnacks => _isDark
      ? AppSpecificColors.categorySnacksDark
      : AppSpecificColors.categorySnacks;

  /// AppSpecificColors.categoryCanned light, AppSpecificColors.categoryCannedDark dark.
  Color get categoryCanned => _isDark
      ? AppSpecificColors.categoryCannedDark
      : AppSpecificColors.categoryCanned;

  /// AppColors.sharedRecipeText light, AppColorsDark.sharedRecipeText dark.
  Color get sharedRecipeText =>
      _isDark ? AppColorsDark.sharedRecipeText : AppColors.sharedRecipeText;

  /// AppColors.sharedRecipeIcon in both modes.
  Color get sharedRecipeIcon => AppColors.sharedRecipeIcon;

  /// AppColors.sharedRecipeBackground light, AppColorsDark.sharedRecipeBackground dark.
  Color get sharedRecipeBackground => _isDark
      ? AppColorsDark.sharedRecipeBackground
      : AppColors.sharedRecipeBackground;

  /// AppColors.focusRing light, AppColorsDark.focusRing dark.
  Color get focusRing =>
      _isDark ? AppColorsDark.focusRing : AppColors.focusRing;

  /// AppColors.progressTrack light, AppColorsDark.progressTrack dark.
  Color get progressTrack =>
      _isDark ? AppColorsDark.progressTrack : AppColors.progressTrack;

  /// AppColors.progressIndicator light, AppColorsDark.progressIndicator dark.
  Color get progressIndicator =>
      _isDark ? AppColorsDark.progressIndicator : AppColors.progressIndicator;

  /// AppColors.surfaceDisabled light, AppColorsDark.surfaceDisabled dark.
  Color get surfaceDisabled =>
      _isDark ? AppColorsDark.surfaceDisabled : AppColors.surfaceDisabled;

  /// semantic surface.tint.warning: the notice surface for information and
  /// to-do boxes. #F0EEE2 light, #2F4437 dark.
  Color get surfaceTintWarning =>
      _isDark ? AppColorsDark.surfaceTintWarning : AppColors.surfaceTintWarning;

  /// semantic surface.tint.danger: the error surface. #F2DDD6 light, #2F4437
  /// dark, so in dark mode the glyph and text carry the kind.
  Color get surfaceTintDanger =>
      _isDark ? AppColorsDark.surfaceTintDanger : AppColors.surfaceTintDanger;

  /// semantic surface.tint.success: the done surface. #DFE8DC light, #2F4437
  /// dark.
  Color get surfaceTintSuccess =>
      _isDark ? AppColorsDark.surfaceTintSuccess : AppColors.surfaceTintSuccess;

  /// Accent text on surface.ink #24382C, as the Hem tonight eyebrow draws
  /// it (Skarmar v12 del 1:47, --r04slot-765: #e09d50 light, #dca968 dark).
  ///
  /// Dark: semantic text.accent, the generated AppColorsDark.textAccent
  /// #DCA968, 5.91:1 on ink, like every other accent text in dark mode
  /// (produktbeslut R6-01 = A, BUT-2197). Light: text.accent is #A15A0A,
  /// which measures 2.37:1 on ink, so light keeps the drawn
  /// AppColors.textAccentOnInk #E09D50, 5.43:1. Both rows are in the
  /// Block 289 contrast contract.
  Color get accentOnInk =>
      _isDark ? AppColorsDark.textAccent : AppColors.textAccentOnInk;

  /// semantic overlay.paperCard: rgba(245,244,237,0.54), delivered as the
  /// generated member cardWhite54. The translucent paper tile that carries
  /// ink text over a photo (produktbeslut B83-3 = A).
  Color get overlayPaperCard =>
      _isDark ? AppColorsDark.cardWhite54 : AppColors.cardWhite54;

  /// semantic text.accent on surface.base: #A15A0A light, #DCA968 dark
  /// (Grafisk manual v6:524). Surface-bound: on surface.raised use
  /// [AppColors.onWarningContainer] / [AppColorsDark.onWarningContainer]
  /// (text.accent.onRaised) instead, and on surface.ink use [accentOnInk].
  Color get textAccent =>
      _isDark ? AppColorsDark.textAccent : AppColors.textAccent;
}

/// `context.modeColors`: the [ModeColors] for the current theme's brightness.
extension ModeColorsAccess on BuildContext {
  /// Reads Theme.of(this).brightness, so dark mode never gets light values.
  ModeColors get modeColors => ModeColors.of(Theme.of(this).brightness);
}
