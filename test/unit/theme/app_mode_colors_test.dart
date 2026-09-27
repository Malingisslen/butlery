/// Parity for ModeColors, the accessor that replaces context.butleryColors
/// (package 7, P7-U00).
///
/// Every ButleryColors member, in light and in dark, must equal the
/// ModeColors member of the same name value by value, so the codemod in
/// tracks A, B and C changes no colour. P7-Z rewrites this against
/// AppColors/AppColorsDark once ButleryColors is gone.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_specific_colors.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

final Map<String, Color Function(ButleryColors)> _legacy = {
  'chatBubbleOutgoing': (ButleryColors c) => c.chatBubbleOutgoing,
  'chatBubbleIncoming': (ButleryColors c) => c.chatBubbleIncoming,
  'chatTextOutgoing': (ButleryColors c) => c.chatTextOutgoing,
  'chatTextIncoming': (ButleryColors c) => c.chatTextIncoming,
  'success': (ButleryColors c) => c.success,
  'onSuccess': (ButleryColors c) => c.onSuccess,
  'successContainer': (ButleryColors c) => c.successContainer,
  'onSuccessContainer': (ButleryColors c) => c.onSuccessContainer,
  'warning': (ButleryColors c) => c.warning,
  'onWarning': (ButleryColors c) => c.onWarning,
  'warningContainer': (ButleryColors c) => c.warningContainer,
  'onWarningContainer': (ButleryColors c) => c.onWarningContainer,
  'info': (ButleryColors c) => c.info,
  'onInfo': (ButleryColors c) => c.onInfo,
  'infoContainer': (ButleryColors c) => c.infoContainer,
  'onInfoContainer': (ButleryColors c) => c.onInfoContainer,
  'neutral': (ButleryColors c) => c.neutral,
  'starGold': (ButleryColors c) => c.starGold,
  'recipeCardLeftBorder': (ButleryColors c) => c.recipeCardLeftBorder,
  'recipeCardBottomBorder': (ButleryColors c) => c.recipeCardBottomBorder,
  'navAccent': (ButleryColors c) => c.navAccent,
  'iconMuted': (ButleryColors c) => c.iconMuted,
  'heroPaleGreen': (ButleryColors c) => c.heroPaleGreen,
  'categoryMeatFish': (ButleryColors c) => c.categoryMeatFish,
  'categoryDairy': (ButleryColors c) => c.categoryDairy,
  'categoryVegetables': (ButleryColors c) => c.categoryVegetables,
  'categoryFruit': (ButleryColors c) => c.categoryFruit,
  'categoryBreadGrains': (ButleryColors c) => c.categoryBreadGrains,
  'categoryFrozen': (ButleryColors c) => c.categoryFrozen,
  'categoryDryGoods': (ButleryColors c) => c.categoryDryGoods,
  'categoryOther': (ButleryColors c) => c.categoryOther,
  'categoryDrinks': (ButleryColors c) => c.categoryDrinks,
  'categoryCleaning': (ButleryColors c) => c.categoryCleaning,
  'categorySnacks': (ButleryColors c) => c.categorySnacks,
  'categoryCanned': (ButleryColors c) => c.categoryCanned,
  'sharedRecipeText': (ButleryColors c) => c.sharedRecipeText,
  'sharedRecipeIcon': (ButleryColors c) => c.sharedRecipeIcon,
  'sharedRecipeBackground': (ButleryColors c) => c.sharedRecipeBackground,
  'focusRing': (ButleryColors c) => c.focusRing,
  'progressTrack': (ButleryColors c) => c.progressTrack,
  'progressIndicator': (ButleryColors c) => c.progressIndicator,
  'surfaceDisabled': (ButleryColors c) => c.surfaceDisabled,
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
};

Set<String> _declared(String path, RegExp pattern) => pattern
    .allMatches(File(path).readAsStringSync())
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  group('ModeColors covers every ButleryColors member', () {
    test('the tables name every declared member', () {
      final legacyFields = _declared(
        'lib/theme/butlery_colors_extension.dart',
        RegExp(r'^\s*final Color (\w+);', multiLine: true),
      );
      final modeGetters = _declared(
        'lib/theme/app_mode_colors.dart',
        RegExp(r'^\s*Color get (\w+) =>', multiLine: true),
      );
      expect(legacyFields, hasLength(42));
      expect(_legacy.keys.toSet(), legacyFields);
      expect(_mode.keys.toSet(), legacyFields);
      expect(modeGetters, legacyFields);
    });
  });

  for (final (label, legacy, mode) in [
    ('light', ButleryColors.light, ModeColors.light),
    ('dark', ButleryColors.dark, ModeColors.dark),
  ]) {
    group('parity in $label mode', () {
      for (final name in _legacy.keys) {
        test(name, () {
          expect(_mode[name]!(mode), _legacy[name]!(legacy));
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
