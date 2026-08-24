// BUT-1860: the category auto-suggestion behind the add-item dialog — type
// "mjölk", get "dairy" filled in for you — had no coverage.
//
// The suggester is a private class inside `shopping_item_dialogs.dart` and
// stays private: it is one map and one loop serving exactly one caller, and
// widening it to public purely so a test can import it would trade a real
// production API for test convenience. So each case drives it through that one
// caller, and reads the field the user sees.
//
// ⚠️ READ THIS BEFORE ADDING A CASE. These tests pin what the suggester
// currently DOES. They are NOT a statement that it is right: measured by running
// it, `Rostbiff` and `Kokosmjölk` come back as dairy and `Diskborste` as a drink
// (BUT-1890). `_CategorySuggester` duplicates `IngredientCategorizer`, which
// fixed those and was never ported back.
//
// Two precisions, because the tempting shorthand is wrong in both directions:
//   · `Ostbågar` is dairy in BOTH engines. The central cheese rule deliberately
//     allows a LEADING `ost` ("ostskiva"), so routing does not fix that row.
//   · `meatFish`/`fruitVeg` below are not retired everywhere — they are still
//     stored, still listed in `ShoppingCategory.all`, and still user-selectable
//     in the category picker. What BUT-1004 changed is that the maintained
//     categorizer no longer PRODUCES them. This class still does.
//
// The value of pinning a duplicate is that it cannot drift further while it
// waits to be deleted.
//
// WHEN BUT-1890 LANDS: re-derive EVERY expectation in this file against
// `IngredientCategorizer`. Do not restore a legacy bucket to keep a test green —
// a red here is the migration doing its job, not a regression.
//
// This comment deliberately does NOT enumerate which cases go red. Two attempts
// to write that ledger were both wrong, each in a new quantifier ("all six are
// fixed centrally" — `Ostbågar` is not; "the eight buckets go red" — `Mjölk` is
// dairy in both). A prediction about code that does not exist yet cannot be
// checked by anything here, so it rots the moment it is written. Derive it then;
// only the two facts below are stable, and both are load-bearing:
//
//   · EXACTLY TWO cases never reach the map, so a red in them IS a real
//     regression: `an empty name suggests nothing` and `typing a name after
//     picking a category leaves it alone`. Both return before the suggester runs.
//   · `an unrecognised name suggests nothing` ('Diskmedel') is the alarm for the
//     null trap documented on `_CategorySuggester`: `categorize` returns
//     `ShoppingCategory.other`, never null, so a naive delegation stamps `other`
//     into every unknown item and reddens this case. That red is the trap, not
//     the migration — map `other` back to null.
//
// The manual-edit guard gets its own cases because it is the half that decides
// whether the feature is helpful or infuriating: a suggestion that overwrites a
// category the user chose is worse than no suggestion at all.

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
    // One case per bucket the map defines, so a bucket deleted or re-pointed
    // at the wrong constant reddens. The values are the raw storage keys
    // (`ShoppingCategory.*`), which is what the field holds and what is saved —
    // the Swedish display name is a separate mapping the dialog never touches.
    final byBucket = <String, String>{
      'Mjölk': ShoppingCategory.dairy,
      'Tomater': ShoppingCategory.fruitVeg,
      'Kyckling': ShoppingCategory.meatFish,
      'Knäckebröd': ShoppingCategory.breadGrain,
      'Havregryn': ShoppingCategory.pantry,
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
    // what decides. Picking the fixture is the work: the lookup is an unbounded
    // SUBSTRING match and the drinks bucket lists the two-letter 'te', so
    // 'Diskborste' — the obvious choice — categorises as a drink. 'Diskmedel'
    // contains no listed keyword at all.
    testWidgets('an unrecognised name suggests nothing', (tester) async {
      expect(await suggestionFor(tester, 'Diskmedel'), isEmpty);
    });

    // The wrong answers named in this file's header and on `_CategorySuggester`
    // itself, pinned — because a table of measurements living only in prose rots
    // silently, and this one is the stated justification for BUT-1890.
    //
    // These are DEFECTS recorded as tests, not desired behaviour. Each one goes
    // red when BUT-1890 routes the suggester through `IngredientCategorizer`,
    // and that red means the fix landed. `Ostbågar` is deliberately NOT here:
    // the central engine answers dairy for it too, so it is not BUT-1890's to
    // fix and pinning it would send the next reader hunting a bug that is a
    // deliberate rule about Swedish compounds.
    final knownWrong = <String, String>{
      'Rostbiff': ShoppingCategory.dairy, // meat; `ost` matches mid-compound
      'Kokosmjölk': ShoppingCategory.dairy, // canned; `mjölk` wins first
      'Diskborste': ShoppingCategory.drinks, // not a drink; two-letter `te`
    };

    knownWrong.forEach((name, wrongAnswer) {
      testWidgets('KNOWN DEFECT (BUT-1890): "$name" suggests $wrongAnswer', (
        tester,
      ) async {
        expect(await suggestionFor(tester, name), wrongAnswer);
      });
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
