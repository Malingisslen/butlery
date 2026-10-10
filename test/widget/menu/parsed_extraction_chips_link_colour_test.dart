// The "refine the prompt" link under the parsed menu chips is link text, so it
// takes text.link of the current mode (ModeColors.textLink). The generated
// linkSmall style bakes the light value only, so dark mode is where a missing
// override shows.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/menu/parsed_extraction_chips.dart';

void main() {
  final refinePrompt = AppLocalizationsSv().weeklyMenuChipsRefinePrompt;

  const parsed = ParsedMenuRequest(
    slotRequests: [],
    globalAllergenAvoid: {},
    globalDietaryRequire: {},
    dayPins: [],
    trace: ExtractionTrace(notUnderstood: ['fancy']),
    rawPrompt: 'something fancy',
  );

  for (final (mode, theme, expected) in [
    ('light', AppTheme.lightTheme, AppColors.textLink),
    ('dark', AppTheme.darkTheme, AppColorsDark.textLink),
  ]) {
    testWidgets('the refine-prompt link is text.link in $mode mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ParsedExtractionChips(parsed: parsed, onRefinePrompt: () {}),
          ),
        ),
      );

      final link = tester.widget<Text>(find.text(refinePrompt));
      expect(link.style?.color, expected);
    });
  }

  // BUT-1821: the "not understood" heading is text and takes text.warning.
  for (final (mode, theme, expected) in [
    ('light', AppTheme.lightTheme, AppColors.textWarning),
    ('dark', AppTheme.darkTheme, AppColorsDark.textWarning),
  ]) {
    testWidgets('the not-understood heading is text.warning in $mode mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: ParsedExtractionChips(parsed: parsed)),
        ),
      );
      final heading = tester.widget<Text>(
        find.text(AppLocalizationsSv().weeklyMenuChipsNotUnderstood),
      );
      expect(heading.style?.color, expected);
    });
  }
}
