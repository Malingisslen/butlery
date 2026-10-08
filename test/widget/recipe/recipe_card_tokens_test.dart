// BUT-2183 5g: the recipe card's chips, notices and glyphs leave the old
// opacity steps. A chip is surface.raised with a border.subtle line (or
// surface.base once the card itself is the raised, selected surface), a notice
// is the mode's surface tint with no border (B83-2), and a dimmed glyph is
// text.disabled.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../test_support/base_unit_test.dart';

TagResult _tagResult({String? version = '1.0'}) => TagResult(
  tags: const {},
  allergenStatus: const {},
  dietaryStatus: const {},
  coverage: 0.0,
  generatedAt: DateTime(2026, 1, 1),
  generatorVersion: version,
  hasCoverageAnomaly: false,
);

Recipe _recipe({TagResult? tagResult, List<String>? personalTagIds}) {
  final builder = RecipeBuilder()
    ..id = 'tokens'
    ..title = 'Ett recept'
    ..imageUrls = [];
  if (tagResult != null) builder.withTagResult(tagResult);
  if (personalTagIds != null) builder.tags = personalTagIds;
  return builder.build();
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<ThemeData> pump(
    WidgetTester tester, {
    required ThemeData theme,
    required RecipeCard card,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 360, child: card)),
        ),
      ),
    );
    return theme;
  }

  BoxDecoration decorationAround(WidgetTester tester, Finder inner) {
    final box = find.ancestor(of: inner, matching: find.byType(Container));
    return tester.widget<Container>(box.first).decoration! as BoxDecoration;
  }

  Color glyphColor(WidgetTester tester, IconData icon) => tester
      .widget<ButleryIcon>(
        find.byWidgetPredicate((w) => w is ButleryIcon && w.icon == icon),
      )
      .color!;

  Color textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('RecipeCard tokens ($name)', () {
      testWidgets('match badge is surface.raised with an outlineVariant line, '
          'surface.base when the card is selected', (tester) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(),
            style: RecipeCardStyle.detailed,
            matchPercent: 0.85,
          ),
        );
        var decoration = decorationAround(tester, find.text('85%'));
        expect(decoration.color, cs.surfaceContainerHighest);
        expect((decoration.border! as Border).top.color, cs.outlineVariant);
        expect(textColor(tester, '85%'), cs.onSurface);

        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(),
            style: RecipeCardStyle.detailed,
            matchPercent: 0.85,
            isSelected: true,
          ),
        );
        decoration = decorationAround(tester, find.text('85%'));
        expect(decoration.color, cs.surface);
      });

      testWidgets('personal tag and overflow chip are surface.raised with an '
          'outlineVariant line, the overflow count is text.secondary', (
        tester,
      ) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(personalTagIds: const ['a', 'b']),
            style: RecipeCardStyle.detailed,
            showPersonalTags: true,
            personalTagNames: const {'a': 'Snabbt', 'b': 'Veckomat'},
            maxPersonalTags: 1,
          ),
        );
        for (final text in ['Snabbt', '+1']) {
          final decoration = decorationAround(tester, find.text(text));
          expect(decoration.color, cs.surfaceContainerHighest, reason: text);
          expect(
            (decoration.border! as Border).top.color,
            cs.outlineVariant,
            reason: text,
          );
        }
        expect(textColor(tester, 'Snabbt'), cs.onSurface);
        expect(
          textColor(tester, '+1'),
          AppModeColors.textSecondaryOnRaised(theme.brightness),
        );
      });

      testWidgets('analysing notice is the warning tint, no border, '
          'textWarning', (tester) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(),
            style: RecipeCardStyle.detailed,
            showAllergenBadges: true,
            showAnalysisStatus: true,
          ),
        );
        final decoration = decorationAround(tester, find.text('Analyseras...'));
        expect(decoration.color, modeColors.surfaceTintWarning);
        expect(decoration.border, isNull);
        final warning = AppModeColors.textWarning(theme.brightness);
        expect(textColor(tester, 'Analyseras...'), warning);
        expect(glyphColor(tester, ButleryIcons.hourglass), warning);
      });

      testWidgets('failed-analysis notice is the danger tint, no border, '
          'onErrorContainer', (tester) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(tagResult: _tagResult(version: 'failed')),
            style: RecipeCardStyle.detailed,
            showAllergenBadges: true,
            showAnalysisStatus: true,
          ),
        );
        final label = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.color == cs.onErrorContainer &&
              (w.data ?? '').isNotEmpty,
        );
        expect(label, findsOneWidget);
        final decoration = decorationAround(tester, label);
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(
          glyphColor(tester, ButleryIcons.triangleAlert),
          cs.onErrorContainer,
        );
      });

      testWidgets('unassessed and completeness markers are surface.raised with '
          'text.secondary text and glyph', (tester) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(tagResult: _tagResult()),
            style: RecipeCardStyle.detailed,
            showAllergenBadges: true,
            userAllergenPrefs: const {'gluten'},
          ),
        );
        final secondary = AppModeColors.textSecondaryOnRaised(theme.brightness);
        // The same card is also incomplete, so one pump covers both markers.
        for (final text in ['Allergener ej bedömda', '65% komplett']) {
          expect(
            decorationAround(tester, find.text(text)).color,
            cs.surfaceContainerHighest,
            reason: text,
          );
          expect(textColor(tester, text), secondary, reason: text);
          // The line keeps the marker visible once the card itself turns
          // surface.raised under a hover or press, which is its own fill.
          final border =
              decorationAround(tester, find.text(text)).border! as Border;
          expect(border.top.color, cs.outlineVariant, reason: text);
          expect(border.top.width, 1, reason: text);
        }
        expect(glyphColor(tester, ButleryIcons.info), secondary);
        expect(glyphColor(tester, ButleryIcons.barChart), secondary);
      });

      testWidgets(
        'the photo-less placeholder is the title initial on surface.raised in '
        'text.secondary, with no vegetable',
        (tester) async {
          for (final style in [
            RecipeCardStyle.detailed,
            RecipeCardStyle.grid,
          ]) {
            await pump(
              tester,
              theme: theme,
              card: RecipeCard(recipe: _recipe(), style: style),
            );
            final plate = find.byType(RecipeInitialPlate);
            expect(plate, findsOneWidget, reason: style.name);
            expect(find.byType(VegetableIllustration), findsNothing);
            expect(
              tester
                  .widget<ColoredBox>(
                    find.descendant(
                      of: plate,
                      matching: find.byType(ColoredBox),
                    ),
                  )
                  .color,
              cs.surfaceContainerHighest,
              reason: style.name,
            );
            final letter = tester.widget<Text>(
              find.descendant(of: plate, matching: find.text('E')),
            );
            expect(letter.style!.color, cs.onSurfaceVariant);
          }
        },
      );

      testWidgets('visibility glyph is text.disabled', (tester) async {
        await pump(
          tester,
          theme: theme,
          card: RecipeCard(
            recipe: _recipe(),
            style: RecipeCardStyle.detailed,
          ),
        );
        expect(
          glyphColor(tester, ButleryIcons.lock),
          AppModeColors.textDisabled(theme.brightness),
        );
      });
    });
  }
}
