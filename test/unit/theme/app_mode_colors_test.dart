/// Parity for ModeColors, the accessor that replaced the retired
/// compatibility theme extension (package 7, P7-U00 and P7-Z).
///
/// Every member, in light and in dark, must equal the generated AppColors,
/// AppColorsDark or AppSpecificColors member the retired extension carried
/// at 3a68d5318 (lib/theme/butlery_colors_extension.dart, deleted in P7-Z),
/// so the retirement changes no colour.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_specific_colors.dart';

/// (light, dark) per member: the generated member each mode read before the
/// extension was retired.
const Map<String, (Color, Color)> _expected = {
  'chatBubbleOutgoing': (
    AppColors.chatBubbleOutgoing,
    AppColorsDark.chatBubbleOutgoing,
  ),
  'chatBubbleIncoming': (
    AppColors.chatBubbleIncoming,
    AppColorsDark.chatBubbleIncoming,
  ),
  'chatTextOutgoing': (
    AppColors.chatTextOutgoing,
    AppColorsDark.chatTextOutgoing,
  ),
  'chatTextIncoming': (
    AppColors.chatTextIncoming,
    AppColorsDark.chatTextIncoming,
  ),
  'success': (AppColors.success, AppColorsDark.success),
  'onSuccess': (AppColors.onSuccess, AppColorsDark.onSuccess),
  'successContainer': (
    AppColors.successContainer,
    AppColorsDark.successContainer,
  ),
  'onSuccessContainer': (
    AppColors.onSuccessContainer,
    AppColorsDark.onSuccessContainer,
  ),
  'warning': (AppColors.warning, AppColorsDark.warning),
  'onWarning': (AppColors.onWarning, AppColorsDark.onWarning),
  'warningContainer': (
    AppColors.warningContainer,
    AppColorsDark.warningContainer,
  ),
  'onWarningContainer': (
    AppColors.onWarningContainer,
    AppColorsDark.onWarningContainer,
  ),
  'info': (AppColors.info, AppColorsDark.info),
  'onInfo': (AppColors.onInfo, AppColorsDark.onInfo),
  'infoContainer': (AppColors.infoContainer, AppColorsDark.infoContainer),
  'onInfoContainer': (AppColors.onInfoContainer, AppColorsDark.onInfoContainer),
  'neutral': (AppColors.neutralMedium, AppColors.neutralMedium),
  'starGold': (AppColors.starGold, AppColors.starGold),
  'recipeCardLeftBorder': (
    AppColors.recipeCardLeftBorder,
    AppColorsDark.recipeCardLeftBorder,
  ),
  'recipeCardBottomBorder': (
    AppColors.recipeCardBottomBorder,
    AppColorsDark.recipeCardBottomBorder,
  ),
  'navAccent': (AppColors.navSelectedIndicator, AppColors.navSelectedIndicator),
  'iconMuted': (AppColors.greenMuted, AppColorsDark.greenMuted),
  'heroPaleGreen': (AppColors.greenPale, AppColorsDark.greenPale),
  'categoryMeatFish': (AppColors.categoryMeatFish, AppColors.categoryMeatFish),
  'categoryDairy': (AppColors.categoryDairy, AppColors.categoryDairy),
  'categoryVegetables': (
    AppColors.categoryVegetables,
    AppColors.categoryVegetables,
  ),
  'categoryFruit': (AppColors.categoryFruit, AppColors.categoryFruit),
  'categoryBreadGrains': (
    AppColors.categoryBreadGrains,
    AppColors.categoryBreadGrains,
  ),
  'categoryFrozen': (AppColors.categoryFrozen, AppColors.categoryFrozen),
  'categoryDryGoods': (AppColors.categoryDryGoods, AppColors.categoryDryGoods),
  'categoryOther': (AppColors.categoryOther, AppColors.categoryOther),
  'categoryDrinks': (
    AppSpecificColors.categoryDrinks,
    AppSpecificColors.categoryDrinksDark,
  ),
  'categoryCleaning': (
    AppSpecificColors.categoryCleaning,
    AppSpecificColors.categoryCleaningDark,
  ),
  'categorySnacks': (
    AppSpecificColors.categorySnacks,
    AppSpecificColors.categorySnacksDark,
  ),
  'categoryCanned': (
    AppSpecificColors.categoryCanned,
    AppSpecificColors.categoryCannedDark,
  ),
  'sharedRecipeText': (
    AppColors.sharedRecipeText,
    AppColorsDark.sharedRecipeText,
  ),
  'sharedRecipeIcon': (AppColors.sharedRecipeIcon, AppColors.sharedRecipeIcon),
  'sharedRecipeBackground': (
    AppColors.sharedRecipeBackground,
    AppColorsDark.sharedRecipeBackground,
  ),
  'focusRing': (AppColors.focusRing, AppColorsDark.focusRing),
  'progressTrack': (AppColors.progressTrack, AppColorsDark.progressTrack),
  'progressIndicator': (
    AppColors.progressIndicator,
    AppColorsDark.progressIndicator,
  ),
  'surfaceDisabled': (AppColors.surfaceDisabled, AppColorsDark.surfaceDisabled),
  // Hem tonight eyebrow on ink (produktbeslut R6-01 = A): the drawn
  // saffronLight in light, text.accent in dark.
  'accentOnInk': (AppColors.textAccentOnInk, AppColorsDark.textAccent),
};

final Map<String, Color Function(ModeColors)> _mode = {
  'chatBubbleOutgoing': (ModeColors c) => c.chatBubbleOutgoing,
  'chatBubbleIncoming': (ModeColors c) => c.chatBubbleIncoming,
  'chatTextOutgoing': (ModeColors c) => c.chatTextOutgoing,
  'chatTextIncoming': (ModeColors c) => c.chatTextIncoming,
  'success': (ModeColors c) => c.success,
  'onSuccess': (ModeColors c) => c.onSuccess,
  'successContainer': (ModeColors c) => c.successContainer,
  'onSuccessContainer': (ModeColors c) => c.onSuccessContainer,
  'warning': (ModeColors c) => c.warning,
  'onWarning': (ModeColors c) => c.onWarning,
  'warningContainer': (ModeColors c) => c.warningContainer,
  'onWarningContainer': (ModeColors c) => c.onWarningContainer,
  'info': (ModeColors c) => c.info,
  'onInfo': (ModeColors c) => c.onInfo,
  'infoContainer': (ModeColors c) => c.infoContainer,
  'onInfoContainer': (ModeColors c) => c.onInfoContainer,
  'neutral': (ModeColors c) => c.neutral,
  'starGold': (ModeColors c) => c.starGold,
  'recipeCardLeftBorder': (ModeColors c) => c.recipeCardLeftBorder,
  'recipeCardBottomBorder': (ModeColors c) => c.recipeCardBottomBorder,
  'navAccent': (ModeColors c) => c.navAccent,
  'iconMuted': (ModeColors c) => c.iconMuted,
  'heroPaleGreen': (ModeColors c) => c.heroPaleGreen,
  'categoryMeatFish': (ModeColors c) => c.categoryMeatFish,
  'categoryDairy': (ModeColors c) => c.categoryDairy,
  'categoryVegetables': (ModeColors c) => c.categoryVegetables,
  'categoryFruit': (ModeColors c) => c.categoryFruit,
  'categoryBreadGrains': (ModeColors c) => c.categoryBreadGrains,
  'categoryFrozen': (ModeColors c) => c.categoryFrozen,
  'categoryDryGoods': (ModeColors c) => c.categoryDryGoods,
  'categoryOther': (ModeColors c) => c.categoryOther,
  'categoryDrinks': (ModeColors c) => c.categoryDrinks,
  'categoryCleaning': (ModeColors c) => c.categoryCleaning,
  'categorySnacks': (ModeColors c) => c.categorySnacks,
  'categoryCanned': (ModeColors c) => c.categoryCanned,
  'sharedRecipeText': (ModeColors c) => c.sharedRecipeText,
  'sharedRecipeIcon': (ModeColors c) => c.sharedRecipeIcon,
  'sharedRecipeBackground': (ModeColors c) => c.sharedRecipeBackground,
  'focusRing': (ModeColors c) => c.focusRing,
  'progressTrack': (ModeColors c) => c.progressTrack,
  'progressIndicator': (ModeColors c) => c.progressIndicator,
  'surfaceDisabled': (ModeColors c) => c.surfaceDisabled,
  'accentOnInk': (ModeColors c) => c.accentOnInk,
};

void main() {
  test('the tables name every ModeColors member', () {
    final modeGetters = RegExp(r'^\s*Color get (\w+) =>', multiLine: true)
        .allMatches(File('lib/theme/app_mode_colors.dart').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    expect(modeGetters, hasLength(43));
    expect(_expected.keys.toSet(), modeGetters);
    expect(_mode.keys.toSet(), modeGetters);
  });

  for (final (label, mode, pick) in [
    ('light', ModeColors.light, ((Color, Color) e) => e.$1),
    ('dark', ModeColors.dark, ((Color, Color) e) => e.$2),
  ]) {
    group('parity in $label mode', () {
      for (final name in _expected.keys) {
        test(name, () {
          expect(_mode[name]!(mode), pick(_expected[name]!));
        });
      }
    });
  }

  group('the documented exceptions stay pinned', () {
    test('iconMuted is greenMuted, heroPaleGreen is greenPale', () {
      expect(ModeColors.light.iconMuted, AppColors.greenMuted);
      expect(ModeColors.dark.iconMuted, AppColorsDark.greenMuted);
      expect(ModeColors.light.heroPaleGreen, AppColors.greenPale);
      expect(ModeColors.dark.heroPaleGreen, AppColorsDark.greenPale);
    });

    test('drinks, cleaning, snacks and canned come from AppSpecificColors', () {
      expect(ModeColors.light.categoryDrinks, AppSpecificColors.categoryDrinks);
      expect(
        ModeColors.dark.categoryDrinks,
        AppSpecificColors.categoryDrinksDark,
      );
      expect(
        ModeColors.light.categoryCleaning,
        AppSpecificColors.categoryCleaning,
      );
      expect(
        ModeColors.dark.categoryCleaning,
        AppSpecificColors.categoryCleaningDark,
      );
      expect(ModeColors.light.categorySnacks, AppSpecificColors.categorySnacks);
      expect(
        ModeColors.dark.categorySnacks,
        AppSpecificColors.categorySnacksDark,
      );
      expect(ModeColors.light.categoryCanned, AppSpecificColors.categoryCanned);
      expect(
        ModeColors.dark.categoryCanned,
        AppSpecificColors.categoryCannedDark,
      );
    });
  });

  group('ModeColors.of and context.modeColors', () {
    test('of picks the set for the brightness', () {
      expect(ModeColors.of(Brightness.light), same(ModeColors.light));
      expect(ModeColors.of(Brightness.dark), same(ModeColors.dark));
      expect(ModeColors.light.brightness, Brightness.light);
      expect(ModeColors.dark.brightness, Brightness.dark);
    });

    for (final brightness in Brightness.values) {
      testWidgets('context.modeColors follows a ${brightness.name} theme', (
        tester,
      ) async {
        late ModeColors read;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) {
                read = context.modeColors;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(read, same(ModeColors.of(brightness)));
      });
    }
  });

  test('app_mode_colors.dart holds no colour literal', () {
    final source = File('lib/theme/app_mode_colors.dart').readAsStringSync();
    expect(RegExp(r'Color\(0x').hasMatch(source), isFalse);
    expect(RegExp(r'Color\.from').hasMatch(source), isFalse);
  });
}
