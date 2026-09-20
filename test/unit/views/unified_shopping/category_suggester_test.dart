// BUT-1860: the category auto-suggestion behind the add-item dialog — type
// "mjölk", get "dairy" filled in for you — had no coverage.
//
// The suggester is a private class inside `shopping_item_dialogs.dart` and
// stays private: since BUT-1890 it is a two-line delegation to
// `IngredientCategorizer` serving exactly one caller, and widening it to public
// purely so a test can import it would trade a real production API for test
// convenience. So each case drives it through that one caller, and reads the
// field the user sees.
//
// What this file is FOR, now that the engine has its own vocabulary suite
// (`test/unit/services/shopping/ingredient_categorizer_vocabulary_test.dart`):
// the wiring, not the word list. One case per bucket proves the raw storage key
// reaches the field; the rest prove the three things only the dialog can get
// wrong.
//
//   · `an unrecognised name suggests nothing` ('Diskmedel') is the alarm for the
//     null trap: `categorize` returns `ShoppingCategory.other`, never null, so a
//     delegation that forgets to map it back stamps "Övrigt" into every unknown
//     item and reddens this case.
//   · `typing a name after picking a category leaves it alone` returns before
//     the suggester runs.
//   · The manual-edit guard gets its own cases because it is the half that
//     decides whether the feature is helpful or infuriating: a suggestion that
//     overwrites a category the user chose is worse than no suggestion at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

void main() {
  late MockUnifiedShoppingViewModel viewModel;

  setUp(() {
    viewModel = MockUnifiedShoppingViewModel();
  });

  Finder fieldLabelled(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

  String textIn(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(fieldLabelled(label)).controller!.text;

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => ShoppingItemDialogs.showAddItemDialog(
              ctx,
              viewModel,
              (_) {},
              (_) {},
            ),
            child: const Text('öppna'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
  }

  /// Types [name] into the item-name field and returns whatever the suggester
  /// put in the category field.
  Future<String> suggestionFor(WidgetTester tester, String name) async {
    await openAddDialog(tester);
    await tester.enterText(fieldLabelled('Varunamn'), name);
    await tester.pump();
    return textIn(tester, 'Kategori');
  }

  group('a typed item name suggests a category', () {
    // One case per bucket the engine can answer, so a bucket that stops
    // reaching the field reddens. The values are the raw storage keys
    // (`ShoppingCategory.*`), which is what the field holds and what is saved —
    // the Swedish display name is a separate mapping the dialog never touches.
    final byBucket = <String, String>{
      'Mjölk': ShoppingCategory.dairy,
      'Tomater': ShoppingCategory.veg,
      'Äpplen': ShoppingCategory.fruit,
      'Kyckling': ShoppingCategory.meat,
      'Lax': ShoppingCategory.fish,
      'Knäckebröd': ShoppingCategory.breadGrain,
      'Havregryn': ShoppingCategory.dryGoods,
      'Ketchup': ShoppingCategory.pantry,
      'Bönor': ShoppingCategory.canned,
      'Curry': ShoppingCategory.spices,
      'Kaffe': ShoppingCategory.drinks,
      'Glass': ShoppingCategory.frozen,
      'Chips': ShoppingCategory.snacks,
    };

    byBucket.forEach((name, expected) {
      testWidgets('"$name" suggests $expected', (tester) async {
        expect(await suggestionFor(tester, name), expected);
      });
    });

    // The lookup is a substring match on the lowercased name, so it has to
    // survive both the casing a user actually types and the words they put
    // around the keyword.
    testWidgets('the match is case-insensitive and works mid-phrase', (
      tester,
    ) async {
      expect(
        await suggestionFor(tester, 'Ekologisk MJÖLK 3%'),
        ShoppingCategory.dairy,
      );
    });

    // The guard here is that an unknown name leaves the field ALONE rather
    // than guessing a bucket, so the save's own `isEmpty -> other` fallback is
    // what decides.
    testWidgets('an unrecognised name suggests nothing', (tester) async {
      expect(await suggestionFor(tester, 'Diskmedel'), isEmpty);
    });

    // The three answers BUT-1890 existed to fix, re-pinned through the dialog
    // rather than only at the engine — the routing is what makes them right
    // here, and a revert to a local map would redden exactly these.
    final wasWrong = <String, String>{
      'Rostbiff': ShoppingCategory.meat,
      'Kokosmjölk': ShoppingCategory.canned,
    };

    wasWrong.forEach((name, expected) {
      testWidgets('"$name" suggests $expected', (tester) async {
        expect(await suggestionFor(tester, name), expected);
      });
    });

    // The third one has no bucket to land in: the engine has no cleaning rule,
    // so a dishbrush leaves the field alone instead of claiming to be a drink.
    testWidgets('"Diskborste" suggests nothing', (tester) async {
      expect(await suggestionFor(tester, 'Diskborste'), isEmpty);
    });

    testWidgets('an empty name suggests nothing', (tester) async {
      expect(await suggestionFor(tester, ''), isEmpty);
    });
  });

  group('a category the user chose is never overwritten', () {
    testWidgets('typing a name after picking a category leaves it alone', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Kategori'), 'spices');
      await tester.pump();
      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.pump();

      expect(
        textIn(tester, 'Kategori'),
        'spices',
        reason:
            'The suggester must yield to a manual choice — silently replacing '
            'it is the failure this guard exists for.',
      );
    });

    // The counterpart, and the reason the guard is not simply "the field is
    // non-empty": the suggester writes into that same field, so a naive check
    // would latch after its own first write and never refine a suggestion as
    // the user keeps typing.
    testWidgets('a suggestion refines as the name grows', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Kaffe');
      await tester.pump();
      expect(textIn(tester, 'Kategori'), ShoppingCategory.drinks);

      await tester.enterText(fieldLabelled('Varunamn'), 'Kaffebröd');
      await tester.pump();
      expect(textIn(tester, 'Kategori'), ShoppingCategory.breadGrain);
    });
  });
}
