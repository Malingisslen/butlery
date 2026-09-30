/// P6-U02: the merge sheet (Skarmar v12 del 2 #inkopmerge, #inkopmergeoppen).
///
/// Summary first: the line "N rätter ger M rader. Efter sammanslagning blir
/// det K varor." and three figures. "Visa detaljer" opens all four switches;
/// "Ersätt listan" is always off by default. The hero says what will be
/// written, the pantry's degraded mode is said with a retry
/// (produktregler.md:697), and nothing is written by the sheet itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';

Recipe _recipe(String id, List<RecipeIngredient> entries) => Recipe(
  core: RecipeCore(
    id: id,
    title: id,
    description: '',
    ingredients: entries.map((e) => e.raw).toList(),
    structuredIngredients: entries,
    instructions: const ['x'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

RecipeIngredient _ing(double amount, String unit, String name) =>
    RecipeIngredient(amount: amount, unit: unit, name: name, raw: name);

/// 3 dishes, 6 rows, 3 items after merging (1 row converted).
final _source = MenuShoppingListGenerator.sourceForMenu({
  'Middag': [
    _recipe('r1', [_ing(1, 'st', 'gul lök'), _ing(2, 'dl', 'mjölk')]),
    _recipe('r2', [_ing(1, 'st', 'gul lök'), _ing(100, 'ml', 'mjölk')]),
    _recipe('r3', [_ing(1, 'st', 'gul lök'), _ing(500, 'g', 'pasta')]),
  ],
}, DateTime(2026, 6, 10));

final _pasta = PantryItem(
  id: 'p1',
  ingredientName: 'pasta',
  quantity: 1,
  unit: 'kg',
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 6, 1),
);

class _Harness {
  MenuShoppingMergePreview? result;
  bool closed = false;
  int retries = 0;
}

Future<_Harness> _open(
  WidgetTester tester, {
  ThemeData? theme,
  MenuShoppingPantry pantry = const MenuShoppingPantry.read([]),
  MenuShoppingPantry retryAnswer = const MenuShoppingPantry.read([]),
  bool canReplace = true,
}) async {
  final harness = _Harness();
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              harness.result = await showShoppingMergeSheet(
                context,
                source: _source,
                pantry: pantry,
                retryPantry: () async {
                  harness.retries++;
                  return retryAnswer;
                },
                canReplace: canReplace,
              );
              harness.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

Finder _hero(String label) => find.descendant(
  of: find.byKey(ShoppingMergeSheet.confirmKey),
  matching: find.text(label),
);

void main() {
  testWidgets('summary first: the line, the three figures, Ersätt off '
      '(TR::FLOW::02::veckomeny::till-inköpslistan)', (tester) async {
    await _open(
      tester,
      pantry: MenuShoppingPantry.read([_pasta]),
    );

    expect(find.text('Till inköpslistan'), findsOneWidget);
    final summary = tester.widget<Text>(
      find.byKey(ShoppingMergeSheet.summaryKey),
    );
    expect(
      summary.textSpan!.toPlainText(),
      '3 rätter ger 6 rader. Efter sammanslagning blir det 2 varor.',
    );
    Finder stat(String id, String value) => find.descendant(
      of: find.byKey(ShoppingMergeSheet.statKey(id)),
      matching: find.text(value),
    );
    expect(stat('merged', '3'), findsOneWidget);
    expect(stat('converted', '1'), findsOneWidget);
    expect(stat('atHome', '1'), findsOneWidget);
    expect(
      find.text('Ersätt listan i stället för att lägga till'),
      findsOneWidget,
    );
    expect(
      find.text('Dina egna, manuellt tillagda varor behålls alltid.'),
      findsOneWidget,
    );
    final replace = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(
          ShoppingMergeSheet.switchKey(ShoppingMergeSwitch.replace),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    expect(replace.value, isFalse, reason: 'Ersätt is always off by default');
    expect(_hero('Lägg till 2 varor'), findsOneWidget);
    // Details closed: only Ersätt shows.
    expect(find.text('Slå samman dubbletter'), findsNothing);
  });

  testWidgets('Visa detaljer opens all four switches, and they change what '
      'the hero will add', (tester) async {
    await _open(tester);

    await tester.tap(find.byKey(ShoppingMergeSheet.detailsToggleKey));
    await tester.pumpAndSettle();

    for (final title in [
      'Slå samman dubbletter',
      'Konvertera enheter',
      'Dra bort skafferivaror',
      'Ersätt listan i stället för att lägga till',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Dölj detaljer'), findsOneWidget);
    expect(_hero('Lägg till 3 varor'), findsOneWidget);

    await tester.tap(
      find.byKey(ShoppingMergeSheet.switchKey(ShoppingMergeSwitch.duplicates)),
    );
    await tester.pumpAndSettle();
    expect(_hero('Lägg till 6 varor'), findsOneWidget);

    await tester.tap(
      find.byKey(ShoppingMergeSheet.switchKey(ShoppingMergeSwitch.replace)),
    );
    await tester.pumpAndSettle();
    expect(_hero('Ersätt med 6 varor'), findsOneWidget);
  });

  testWidgets('a list from before recipe rows were tracked: Ersätt is off '
      'and says why, and a tap changes nothing', (tester) async {
    final harness = await _open(tester, canReplace: false);
    final row = find.byKey(
      ShoppingMergeSheet.switchKey(ShoppingMergeSwitch.replace),
    );

    expect(
      find.text(
        'Listan gjordes innan appen höll isär veckans varor och dina egna, '
        'så den kan inte ersättas. Veckans varor läggs till.',
      ),
      findsOneWidget,
    );
    final box = tester.widget<Checkbox>(
      find.descendant(of: row, matching: find.byType(Checkbox)),
    );
    expect(box.onChanged, isNull);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(_hero('Lägg till 3 varor'), findsOneWidget);
    await tester.tap(find.byKey(ShoppingMergeSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(harness.result!.options.replaceList, isFalse);
  });

  testWidgets('what is at home in full is named under the pantry switch', (
    tester,
  ) async {
    await _open(tester, pantry: MenuShoppingPantry.read([_pasta]));
    await tester.tap(find.byKey(ShoppingMergeSheet.detailsToggleKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Finns hemma i tillräcklig mängd: pasta'),
      findsOneWidget,
    );
  });

  testWidgets('an unreadable pantry is said, with Försök igen that reads it '
      'again (produktregler.md:697)', (tester) async {
    final harness = await _open(
      tester,
      pantry: const MenuShoppingPantry.unavailable(),
      retryAnswer: MenuShoppingPantry.read([_pasta]),
    );

    expect(find.byKey(ShoppingMergeSheet.pantryUnavailableKey), findsOneWidget);
    expect(
      find.text(
        'Skafferiet gick inte att läsa, så listan görs utan skafferiavdrag.',
      ),
      findsOneWidget,
    );
    expect(_hero('Lägg till 3 varor'), findsOneWidget);

    await tester.tap(find.byKey(ShoppingMergeSheet.pantryRetryKey));
    await tester.pumpAndSettle();

    expect(harness.retries, 1);
    expect(find.byKey(ShoppingMergeSheet.pantryUnavailableKey), findsNothing);
    expect(_hero('Lägg till 2 varor'), findsOneWidget);
  });

  testWidgets('the hero returns the merge it showed; Avbryt returns nothing '
      'and writes nothing', (tester) async {
    var harness = await _open(tester);
    await tester.tap(find.byKey(ShoppingMergeSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(harness.closed, isTrue);
    expect(harness.result, isNotNull);
    expect(harness.result!.itemCount, 3);
    expect(harness.result!.options.replaceList, isFalse);

    harness = await _open(tester);
    await tester.tap(find.byKey(ShoppingMergeSheet.cancelKey));
    await tester.pumpAndSettle();
    expect(harness.closed, isTrue);
    expect(harness.result, isNull);
  });

  for (final (mode, theme, paper, secondary, link) in [
    (
      'light',
      AppTheme.lightTheme,
      const Color(0xFFF5F4ED),
      const Color(0xFF5B6959),
      const Color(0xFF8A5212),
    ),
    (
      'dark',
      AppTheme.darkTheme,
      const Color(0xFF17251D),
      const Color(0xFFA9B2A0),
      const Color(0xFFDCA968),
    ),
  ]) {
    testWidgets('figures on the sheet paper with text.secondary labels, '
        'Visa detaljer in text.link ($mode)', (tester) async {
      await _open(tester, theme: theme);

      final cell = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.byKey(ShoppingMergeSheet.statKey('merged')),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(cell.color, paper);
      expect(cell.color, theme.bottomSheetTheme.backgroundColor);
      final figureLabel = tester.widget<Text>(find.text('slås samman'));
      expect(figureLabel.style!.color, secondary);
      final summary = tester.widget<Text>(
        find.byKey(ShoppingMergeSheet.summaryKey),
      );
      expect(summary.style!.color, secondary);
      final label = tester.widget<Text>(find.text('Visa detaljer'));
      expect(label.style!.color, link);
      expect(
        ModeColors.of(theme.brightness).info,
        link,
        reason: 'text.link is the info member (app_colors.dart)',
      );
    });
  }

  testWidgets('fits a 320 dp phone with details open, without overflow', (
    tester,
  ) async {
    await _open(tester);
    tester.view.physicalSize = const Size(640, 1400);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ShoppingMergeSheet.detailsToggleKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(ShoppingMergeSheet.confirmKey), findsOneWidget);
  });
}
