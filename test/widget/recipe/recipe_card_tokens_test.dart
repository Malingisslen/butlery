// BUT-2183 5g: the recipe card's chips leave the old opacity steps. A chip is
// surface.raised with a border.subtle line (or surface.base once the card
// itself is the raised, selected surface).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../test_support/base_unit_test.dart';

Recipe _recipe() =>
    (RecipeBuilder()
          ..id = 'tokens'
          ..title = 'Ett recept'
          ..imageUrls = [])
        .build();

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

  Color textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

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
    });
  }
}
