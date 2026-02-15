/// ThemeExtension for Butlery-specific colors that don't map to standard
/// Material 3 ColorScheme roles (chat bubbles, semantic status, categories,
/// brand-specific decorative colors).
///
/// Access via `context.butleryColors` in widgets.

import 'package:flutter/material.dart';

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
    // Brand / decorative
    required this.starGold,
    required this.recipeCardLeftBorder,
    required this.recipeCardBottomBorder,
    required this.navAccent,
    // Categories
    required this.categoryMeatFish,
    required this.categoryDairy,
    required this.categoryVegetables,
    required this.categoryFruit,
    required this.categoryBreadGrains,
    required this.categoryFrozen,
    required this.categoryDryGoods,
    required this.categoryOther,
    // Shared recipe
    required this.sharedRecipeText,
    required this.sharedRecipeIcon,
    required this.sharedRecipeBackground,
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

  // Brand / decorative
  final Color starGold;
  final Color recipeCardLeftBorder;
  final Color recipeCardBottomBorder;
  final Color navAccent;

  // Categories
  final Color categoryMeatFish;
  final Color categoryDairy;
  final Color categoryVegetables;
  final Color categoryFruit;
  final Color categoryBreadGrains;
  final Color categoryFrozen;
  final Color categoryDryGoods;
  final Color categoryOther;

  // Shared recipe
  final Color sharedRecipeText;
  final Color sharedRecipeIcon;
  final Color sharedRecipeBackground;

  /// Light mode values — match current AppColors constants exactly.
  static const light = ButleryColors(
    // Chat
    chatBubbleOutgoing: Color(0xFF6B9B7A), // forestGreenLight
    chatBubbleIncoming: Color(0xFFF0EAD6), // creamDark
    chatTextOutgoing: Color(0xFFFFFFFF), // textOnPrimary
    chatTextIncoming: Color(0xFF2C3E50), // textDark
    // Status: success
    success: Color(0xFF0D9166),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFF0FDF4),
    onSuccessContainer: Color(0xFF166534),
    // Status: warning
    warning: Color(0xFF9D7920),
    onWarning: Color(0xFF2C3E50),
    warningContainer: Color(0xFFFFF8E1),
    onWarningContainer: Color(0xFF8B6914),
    // Status: info
    info: Color(0xFF2563CA),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFF0F9FF),
    onInfoContainer: Color(0xFF1E40AF),
    // Brand / decorative
    starGold: Color(0xFFFBBF24),
    recipeCardLeftBorder: Color(0xFF4A7C59), // forestGreen
    recipeCardBottomBorder: Color(0xFF8B5A3C), // rust
    navAccent: Color(0xFF8B5A3C), // rust
    // Categories
    categoryMeatFish: Color(0xFF8B5A3C), // rust
    categoryDairy: Color(0xFFD4A03C),
    categoryVegetables: Color(0xFF4A7C59), // forestGreen
    categoryFruit: Color(0xFF7CB87C),
    categoryBreadGrains: Color(0xFFC4A35A),
    categoryFrozen: Color(0xFF8BA5B5),
    categoryDryGoods: Color(0xFF9C7A5C),
    categoryOther: Color(0xFF9CA3AF),
    // Shared recipe
    sharedRecipeText: Color(0xFF9CA3AF),
    sharedRecipeIcon: Color(0xFFD1D5DB),
    sharedRecipeBackground: Color(0xFFFAF8F3),
  );

  /// Dark mode values — adapted for dark surfaces while preserving brand identity.
  static const dark = ButleryColors(
    // Chat: brighter outgoing, darker incoming
    chatBubbleOutgoing: Color(0xFF3D6849), // forestGreenDark
    chatBubbleIncoming: Color(0xFF2C2C2C), // dark surface
    chatTextOutgoing: Color(0xFFFFFFFF),
    chatTextIncoming: Color(0xFFE0E0E0),
    // Status: lighter tones on dark (M3 tone 80 pattern)
    success: Color(0xFF6DD49E),
    onSuccess: Color(0xFF003919),
    successContainer: Color(0xFF005229),
    onSuccessContainer: Color(0xFF8FF7B8),
    // Warning
    warning: Color(0xFFE4C56B),
    onWarning: Color(0xFF3D2E00),
    warningContainer: Color(0xFF584400),
    onWarningContainer: Color(0xFFFFE08D),
    // Info
    info: Color(0xFFAAC7FF),
    onInfo: Color(0xFF002F66),
    infoContainer: Color(0xFF00458F),
    onInfoContainer: Color(0xFFD6E3FF),
    // Brand / decorative: slightly desaturated for dark
    starGold: Color(0xFFFFD54F),
    recipeCardLeftBorder: Color(0xFF6B9B7A), // forestGreenLight
    recipeCardBottomBorder: Color(0xFFD4A88A), // rust tone 80
    navAccent: Color(0xFFD4A88A), // rust tone 80
    // Categories: lighter for dark bg contrast
    categoryMeatFish: Color(0xFFD4A88A),
    categoryDairy: Color(0xFFE8C76E),
    categoryVegetables: Color(0xFF6B9B7A),
    categoryFruit: Color(0xFFA0D6A0),
    categoryBreadGrains: Color(0xFFDCC47E),
    categoryFrozen: Color(0xFFB0C8D8),
    categoryDryGoods: Color(0xFFC4A080),
    categoryOther: Color(0xFFBDBDBD),
    // Shared recipe
    sharedRecipeText: Color(0xFFBDBDBD),
    sharedRecipeIcon: Color(0xFF757575),
    sharedRecipeBackground: Color(0xFF2C2C2C),
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
    Color? starGold,
    Color? recipeCardLeftBorder,
    Color? recipeCardBottomBorder,
    Color? navAccent,
    Color? categoryMeatFish,
    Color? categoryDairy,
    Color? categoryVegetables,
    Color? categoryFruit,
    Color? categoryBreadGrains,
    Color? categoryFrozen,
    Color? categoryDryGoods,
    Color? categoryOther,
    Color? sharedRecipeText,
    Color? sharedRecipeIcon,
    Color? sharedRecipeBackground,
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
      starGold: starGold ?? this.starGold,
      recipeCardLeftBorder: recipeCardLeftBorder ?? this.recipeCardLeftBorder,
      recipeCardBottomBorder:
          recipeCardBottomBorder ?? this.recipeCardBottomBorder,
      navAccent: navAccent ?? this.navAccent,
      categoryMeatFish: categoryMeatFish ?? this.categoryMeatFish,
      categoryDairy: categoryDairy ?? this.categoryDairy,
      categoryVegetables: categoryVegetables ?? this.categoryVegetables,
      categoryFruit: categoryFruit ?? this.categoryFruit,
      categoryBreadGrains: categoryBreadGrains ?? this.categoryBreadGrains,
      categoryFrozen: categoryFrozen ?? this.categoryFrozen,
      categoryDryGoods: categoryDryGoods ?? this.categoryDryGoods,
      categoryOther: categoryOther ?? this.categoryOther,
      sharedRecipeText: sharedRecipeText ?? this.sharedRecipeText,
      sharedRecipeIcon: sharedRecipeIcon ?? this.sharedRecipeIcon,
      sharedRecipeBackground:
          sharedRecipeBackground ?? this.sharedRecipeBackground,
    );
  }

  @override
  ButleryColors lerp(ThemeExtension<ButleryColors>? other, double t) {
    if (other is! ButleryColors) return this;
    return ButleryColors(
      chatBubbleOutgoing:
          Color.lerp(chatBubbleOutgoing, other.chatBubbleOutgoing, t)!,
      chatBubbleIncoming:
          Color.lerp(chatBubbleIncoming, other.chatBubbleIncoming, t)!,
      chatTextOutgoing:
          Color.lerp(chatTextOutgoing, other.chatTextOutgoing, t)!,
      chatTextIncoming:
          Color.lerp(chatTextIncoming, other.chatTextIncoming, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
      recipeCardLeftBorder:
          Color.lerp(recipeCardLeftBorder, other.recipeCardLeftBorder, t)!,
      recipeCardBottomBorder:
          Color.lerp(recipeCardBottomBorder, other.recipeCardBottomBorder, t)!,
      navAccent: Color.lerp(navAccent, other.navAccent, t)!,
      categoryMeatFish:
          Color.lerp(categoryMeatFish, other.categoryMeatFish, t)!,
      categoryDairy: Color.lerp(categoryDairy, other.categoryDairy, t)!,
      categoryVegetables:
          Color.lerp(categoryVegetables, other.categoryVegetables, t)!,
      categoryFruit: Color.lerp(categoryFruit, other.categoryFruit, t)!,
      categoryBreadGrains:
          Color.lerp(categoryBreadGrains, other.categoryBreadGrains, t)!,
      categoryFrozen: Color.lerp(categoryFrozen, other.categoryFrozen, t)!,
      categoryDryGoods:
          Color.lerp(categoryDryGoods, other.categoryDryGoods, t)!,
      categoryOther: Color.lerp(categoryOther, other.categoryOther, t)!,
      sharedRecipeText:
          Color.lerp(sharedRecipeText, other.sharedRecipeText, t)!,
      sharedRecipeIcon:
          Color.lerp(sharedRecipeIcon, other.sharedRecipeIcon, t)!,
      sharedRecipeBackground:
          Color.lerp(sharedRecipeBackground, other.sharedRecipeBackground, t)!,
    );
  }
}

/// Convenience accessor for ButleryColors from BuildContext.
extension ButleryColorsAccess on BuildContext {
  ButleryColors get butleryColors =>
      Theme.of(this).extension<ButleryColors>() ?? ButleryColors.light;
}
