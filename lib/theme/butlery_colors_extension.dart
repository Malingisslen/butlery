/// ThemeExtension for Butlery-specific colors that don't map to standard
/// Material 3 ColorScheme roles (chat bubbles, semantic status, categories,
/// brand-specific decorative colors).
///
/// Access via `context.butleryColors` in widgets.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_specific_colors.dart';

/// Custom color slots for Butlery beyond what ColorScheme provides.
class ButleryColors extends ThemeExtension<ButleryColors> {
  const ButleryColors({
    // Chat
    required this.chatBubbleOutgoing,
    required this.chatBubbleIncoming,
    required this.chatTextOutgoing,
    required this.chatTextIncoming,
    // Status: success
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    // Status: warning
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    // Status: info
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    // Status: neutral
    required this.neutral,
    // Brand / decorative
    required this.starGold,
    required this.recipeCardLeftBorder,
    required this.recipeCardBottomBorder,
    required this.navAccent,
    required this.iconMuted,
    required this.heroPaleGreen,
    // Categories
    required this.categoryMeatFish,
    required this.categoryDairy,
    required this.categoryVegetables,
    required this.categoryFruit,
    required this.categoryBreadGrains,
    required this.categoryFrozen,
    required this.categoryDryGoods,
    required this.categoryOther,
    required this.categoryDrinks,
    required this.categoryCleaning,
    required this.categorySnacks,
    required this.categoryCanned,
    // Shared recipe
    required this.sharedRecipeText,
    required this.sharedRecipeIcon,
    required this.sharedRecipeBackground,
    required this.focusRing,
    required this.progressTrack,
    required this.progressIndicator,
    required this.surfaceDisabled,
  });

  // Chat
  final Color chatBubbleOutgoing;
  final Color chatBubbleIncoming;
  final Color chatTextOutgoing;
  final Color chatTextIncoming;

  // Status: success
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  // Status: warning
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  // Status: info
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // Status: neutral — used for low/failed parse confidence pills, muted badges
  final Color neutral;

  // Brand / decorative
  final Color starGold;
  final Color recipeCardLeftBorder;
  final Color recipeCardBottomBorder;
  final Color navAccent;

  /// Muted brand-green for decorative icons (BUT-572 pilot follow-up).
  /// Light: matches legacy `AppColors.greenMuted` (0xFF526A55) so existing
  /// goldens stay byte-identical. Dark: tone-80 lighter equivalent.
  final Color iconMuted;

  /// Pale-green hero/section background tint (BUT-1447). Light: matches legacy
  /// `AppColors.greenPale` (0xFFE8F0EA) exactly so light mode is unchanged.
  /// Dark: a low-chroma green on the warm-dark surface for the same "emphasis"
  /// reading.
  final Color heroPaleGreen;

  // Categories
  final Color categoryMeatFish;
  final Color categoryDairy;
  final Color categoryVegetables;
  final Color categoryFruit;
  final Color categoryBreadGrains;
  final Color categoryFrozen;
  final Color categoryDryGoods;
  final Color categoryOther;
  final Color categoryDrinks;
  final Color categoryCleaning;
  final Color categorySnacks;
  final Color categoryCanned;

  // Shared recipe
  final Color sharedRecipeText;
  final Color sharedRecipeIcon;
  final Color sharedRecipeBackground;

  /// The focus ring: ink #24382C on light, paper #F5F4ED on dark, never
  /// saffron (tokens.json:155-160, semantic.focusRing). Width and offset are
  /// AppDimensions.focusRingWidth and focusRingOffset.
  final Color focusRing;

  /// The plate line's track (tokens.json semantic progressTrack).
  final Color progressTrack;

  /// The plate line's determinate fill (tokens.json semantic
  /// progressIndicator).
  final Color progressIndicator;

  /// The disabled surface, never opacity (tokens.json semantic
  /// surface.disabled).
  final Color surfaceDisabled;

  /// Light mode values — match current AppColors constants exactly.
  /// Ljust läge. Varje värde ägs av den kanoniska grunden — den här klassen
  /// är en kompatibilitetsyta, inte en palett. Pensioneras i paket 7.
  static const light = ButleryColors(
    chatBubbleOutgoing: AppColors.chatBubbleOutgoing,
    chatBubbleIncoming: AppColors.chatBubbleIncoming,
    chatTextOutgoing: AppColors.chatTextOutgoing,
    chatTextIncoming: AppColors.chatTextIncoming,
    success: AppColors.success,
    onSuccess: AppColors.onSuccess,
    successContainer: AppColors.successContainer,
    onSuccessContainer: AppColors.onSuccessContainer,
    warning: AppColors.warning,
    onWarning: AppColors.onWarning,
    warningContainer: AppColors.warningContainer,
    onWarningContainer: AppColors.onWarningContainer,
    info: AppColors.info,
    onInfo: AppColors.onInfo,
    infoContainer: AppColors.infoContainer,
    onInfoContainer: AppColors.onInfoContainer,
    neutral: AppColors.neutralMedium,
    starGold: AppColors.starGold,
    recipeCardLeftBorder: AppColors.recipeCardLeftBorder,
    recipeCardBottomBorder: AppColors.recipeCardBottomBorder,
    navAccent: AppColors.navSelectedIndicator,
    iconMuted: AppColors.greenMuted,
    heroPaleGreen: AppColors.greenPale,
    categoryMeatFish: AppColors.categoryMeatFish,
    categoryDairy: AppColors.categoryDairy,
    categoryVegetables: AppColors.categoryVegetables,
    categoryFruit: AppColors.categoryFruit,
    categoryBreadGrains: AppColors.categoryBreadGrains,
    categoryFrozen: AppColors.categoryFrozen,
    categoryDryGoods: AppColors.categoryDryGoods,
    categoryOther: AppColors.categoryOther,
    categoryDrinks: AppSpecificColors.categoryDrinks,
    categoryCleaning: AppSpecificColors.categoryCleaning,
    categorySnacks: AppSpecificColors.categorySnacks,
    categoryCanned: AppSpecificColors.categoryCanned,
    sharedRecipeText: AppColors.sharedRecipeText,
    sharedRecipeIcon: AppColors.sharedRecipeIcon,
    sharedRecipeBackground: AppColors.sharedRecipeBackground,
    focusRing: AppColors.focusRing,
    progressTrack: AppColors.progressTrack,
    progressIndicator: AppColors.progressIndicator,
    surfaceDisabled: AppColors.surfaceDisabled,
  );

  /// Dark mode values — adapted for dark surfaces while preserving brand identity.
  /// Mörkt läge. Palettfärger saknar lägesberoende och pekar därför på samma
  /// kanoniska medlem i båda lägena; det är designsystemets egen modell.
  static const dark = ButleryColors(
    chatBubbleOutgoing: AppColorsDark.chatBubbleOutgoing,
    chatBubbleIncoming: AppColorsDark.chatBubbleIncoming,
    chatTextOutgoing: AppColorsDark.chatTextOutgoing,
    chatTextIncoming: AppColorsDark.chatTextIncoming,
    success: AppColorsDark.success,
    onSuccess: AppColorsDark.onSuccess,
    successContainer: AppColorsDark.successContainer,
    onSuccessContainer: AppColorsDark.onSuccessContainer,
    warning: AppColorsDark.warning,
    onWarning: AppColorsDark.onWarning,
    warningContainer: AppColorsDark.warningContainer,
    onWarningContainer: AppColorsDark.onWarningContainer,
    info: AppColorsDark.info,
    onInfo: AppColorsDark.onInfo,
    infoContainer: AppColorsDark.infoContainer,
    onInfoContainer: AppColorsDark.onInfoContainer,
    neutral: AppColors.neutralMedium,
    starGold: AppColors.starGold,
    recipeCardLeftBorder: AppColorsDark.recipeCardLeftBorder,
    recipeCardBottomBorder: AppColorsDark.recipeCardBottomBorder,
    navAccent: AppColors.navSelectedIndicator,
    iconMuted: AppColorsDark.greenMuted,
    heroPaleGreen: AppColorsDark.greenPale,
    categoryMeatFish: AppColors.categoryMeatFish,
    categoryDairy: AppColors.categoryDairy,
    categoryVegetables: AppColors.categoryVegetables,
    categoryFruit: AppColors.categoryFruit,
    categoryBreadGrains: AppColors.categoryBreadGrains,
    categoryFrozen: AppColors.categoryFrozen,
    categoryDryGoods: AppColors.categoryDryGoods,
    categoryOther: AppColors.categoryOther,
    categoryDrinks: AppSpecificColors.categoryDrinksDark,
    categoryCleaning: AppSpecificColors.categoryCleaningDark,
    categorySnacks: AppSpecificColors.categorySnacksDark,
    categoryCanned: AppSpecificColors.categoryCannedDark,
    sharedRecipeText: AppColorsDark.sharedRecipeText,
    sharedRecipeIcon: AppColors.sharedRecipeIcon,
    sharedRecipeBackground: AppColorsDark.sharedRecipeBackground,
    focusRing: AppColorsDark.focusRing,
    progressTrack: AppColorsDark.progressTrack,
    progressIndicator: AppColorsDark.progressIndicator,
    surfaceDisabled: AppColorsDark.surfaceDisabled,
  );

  @override
  ButleryColors copyWith({
    Color? chatBubbleOutgoing,
    Color? chatBubbleIncoming,
    Color? chatTextOutgoing,
    Color? chatTextIncoming,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? neutral,
    Color? starGold,
    Color? recipeCardLeftBorder,
    Color? recipeCardBottomBorder,
    Color? navAccent,
    Color? iconMuted,
    Color? heroPaleGreen,
    Color? categoryMeatFish,
    Color? categoryDairy,
    Color? categoryVegetables,
    Color? categoryFruit,
    Color? categoryBreadGrains,
    Color? categoryFrozen,
    Color? categoryDryGoods,
    Color? categoryOther,
    Color? categoryDrinks,
    Color? categoryCleaning,
    Color? categorySnacks,
    Color? categoryCanned,
    Color? sharedRecipeText,
    Color? sharedRecipeIcon,
    Color? sharedRecipeBackground,
    Color? focusRing,
    Color? progressTrack,
    Color? progressIndicator,
    Color? surfaceDisabled,
  }) {
    return ButleryColors(
      chatBubbleOutgoing: chatBubbleOutgoing ?? this.chatBubbleOutgoing,
      chatBubbleIncoming: chatBubbleIncoming ?? this.chatBubbleIncoming,
      chatTextOutgoing: chatTextOutgoing ?? this.chatTextOutgoing,
      chatTextIncoming: chatTextIncoming ?? this.chatTextIncoming,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      neutral: neutral ?? this.neutral,
      starGold: starGold ?? this.starGold,
      recipeCardLeftBorder: recipeCardLeftBorder ?? this.recipeCardLeftBorder,
      recipeCardBottomBorder:
          recipeCardBottomBorder ?? this.recipeCardBottomBorder,
      navAccent: navAccent ?? this.navAccent,
      iconMuted: iconMuted ?? this.iconMuted,
      heroPaleGreen: heroPaleGreen ?? this.heroPaleGreen,
      categoryMeatFish: categoryMeatFish ?? this.categoryMeatFish,
      categoryDairy: categoryDairy ?? this.categoryDairy,
      categoryVegetables: categoryVegetables ?? this.categoryVegetables,
      categoryFruit: categoryFruit ?? this.categoryFruit,
      categoryBreadGrains: categoryBreadGrains ?? this.categoryBreadGrains,
      categoryFrozen: categoryFrozen ?? this.categoryFrozen,
      categoryDryGoods: categoryDryGoods ?? this.categoryDryGoods,
      categoryOther: categoryOther ?? this.categoryOther,
      categoryDrinks: categoryDrinks ?? this.categoryDrinks,
      categoryCleaning: categoryCleaning ?? this.categoryCleaning,
      categorySnacks: categorySnacks ?? this.categorySnacks,
      categoryCanned: categoryCanned ?? this.categoryCanned,
      sharedRecipeText: sharedRecipeText ?? this.sharedRecipeText,
      sharedRecipeIcon: sharedRecipeIcon ?? this.sharedRecipeIcon,
      sharedRecipeBackground:
          sharedRecipeBackground ?? this.sharedRecipeBackground,
      focusRing: focusRing ?? this.focusRing,
      progressTrack: progressTrack ?? this.progressTrack,
      progressIndicator: progressIndicator ?? this.progressIndicator,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
    );
  }

  @override
  ButleryColors lerp(ThemeExtension<ButleryColors>? other, double t) {
    if (other is! ButleryColors) return this;
    return ButleryColors(
      chatBubbleOutgoing: Color.lerp(
        chatBubbleOutgoing,
        other.chatBubbleOutgoing,
        t,
      )!,
      chatBubbleIncoming: Color.lerp(
        chatBubbleIncoming,
        other.chatBubbleIncoming,
        t,
      )!,
      chatTextOutgoing: Color.lerp(
        chatTextOutgoing,
        other.chatTextOutgoing,
        t,
      )!,
      chatTextIncoming: Color.lerp(
        chatTextIncoming,
        other.chatTextIncoming,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
      recipeCardLeftBorder: Color.lerp(
        recipeCardLeftBorder,
        other.recipeCardLeftBorder,
        t,
      )!,
      recipeCardBottomBorder: Color.lerp(
        recipeCardBottomBorder,
        other.recipeCardBottomBorder,
        t,
      )!,
      navAccent: Color.lerp(navAccent, other.navAccent, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      heroPaleGreen: Color.lerp(heroPaleGreen, other.heroPaleGreen, t)!,
      categoryMeatFish: Color.lerp(
        categoryMeatFish,
        other.categoryMeatFish,
        t,
      )!,
      categoryDairy: Color.lerp(categoryDairy, other.categoryDairy, t)!,
      categoryVegetables: Color.lerp(
        categoryVegetables,
        other.categoryVegetables,
        t,
      )!,
      categoryFruit: Color.lerp(categoryFruit, other.categoryFruit, t)!,
      categoryBreadGrains: Color.lerp(
        categoryBreadGrains,
        other.categoryBreadGrains,
        t,
      )!,
      categoryFrozen: Color.lerp(categoryFrozen, other.categoryFrozen, t)!,
      categoryDryGoods: Color.lerp(
        categoryDryGoods,
        other.categoryDryGoods,
        t,
      )!,
      categoryOther: Color.lerp(categoryOther, other.categoryOther, t)!,
      categoryDrinks: Color.lerp(categoryDrinks, other.categoryDrinks, t)!,
      categoryCleaning: Color.lerp(
        categoryCleaning,
        other.categoryCleaning,
        t,
      )!,
      categorySnacks: Color.lerp(categorySnacks, other.categorySnacks, t)!,
      categoryCanned: Color.lerp(categoryCanned, other.categoryCanned, t)!,
      sharedRecipeText: Color.lerp(
        sharedRecipeText,
        other.sharedRecipeText,
        t,
      )!,
      sharedRecipeIcon: Color.lerp(
        sharedRecipeIcon,
        other.sharedRecipeIcon,
        t,
      )!,
      sharedRecipeBackground: Color.lerp(
        sharedRecipeBackground,
        other.sharedRecipeBackground,
        t,
      )!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      progressIndicator: Color.lerp(
        progressIndicator,
        other.progressIndicator,
        t,
      )!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
    );
  }
}

/// Convenience accessor for ButleryColors from BuildContext.
extension ButleryColorsAccess on BuildContext {
  /// A theme without the extension still gets the values of its own mode,
  /// never the light ones in dark mode.
  ButleryColors get butleryColors {
    final theme = Theme.of(this);
    return theme.extension<ButleryColors>() ??
        (theme.brightness == Brightness.dark
            ? ButleryColors.dark
            : ButleryColors.light);
  }
}
