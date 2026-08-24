// BUT-1860: the add/edit shopping-item dialogs had no tests at all — the two
// screens through which every hand-added item on a shopping list is typed.
//
// The suite pins what the user types against what leaves the dialog, because
// that seam is where both defects this batch fixes lived: a field read at save
// time that no input ever filled (BUT-1873), and an erased note that came back
// (BUT-1874). Assertions are taken on the ARGUMENTS handed to the viewmodel
// rather than on the returned model object — the object is an intermediate the
// dialog immediately destructures, and the viewmodel call is what reaches
// Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

void main() {
  late MockUnifiedShoppingViewModel viewModel;
  late List<Invocation> saves;
  late List<String> successes;
  late List<String> errors;

  /// The named arguments of the single save the dialog performed. Reading the
  /// recorded Invocation instead of a `verify(...captureAny...)` per field
  /// keeps the seven- and eight-parameter call sites from drowning the
  /// assertions.
  Map<Symbol, dynamic> savedArgs() {
    expect(saves, hasLength(1), reason: 'expected exactly one save call');
    return saves.single.namedArguments;
  }

  setUp(() {
    viewModel = MockUnifiedShoppingViewModel();
    saves = [];
    successes = [];
    errors = [];

    when(
      () => viewModel.addItemToActiveList(
        name: any(named: 'name'),
        amount: any(named: 'amount'),
        unit: any(named: 'unit'),
        category: any(named: 'category'),
        note: any(named: 'note'),
        estimatedPrice: any(named: 'estimatedPrice'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer((invocation) async {
      saves.add(invocation);
      return true;
    });

    when(
      () => viewModel.updateItem(
        itemId: any(named: 'itemId'),
        name: any(named: 'name'),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        category: any(named: 'category'),
        notes: any(named: 'notes'),
        estimatedPrice: any(named: 'estimatedPrice'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer((invocation) async {
      saves.add(invocation);
      return true;
    });
  });

  /// A field located by its floating label. The label is exact-matched, so it
  /// never collides with the hint text of the same field ('Varunamn' vs
  /// 'Varunamn...').
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
              successes.add,
              errors.add,
            ),
            child: const Text('öppna'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
  }

  Future<void> openEditDialog(
    WidgetTester tester,
    UnifiedShoppingItem item,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => ShoppingItemDialogs.showEditItemDialog(
              ctx,
              item,
              viewModel,
              successes.add,
              errors.add,
            ),
            child: const Text('öppna'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
  }

  group('add item dialog', () {
    testWidgets('name and note reach the save', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.enterText(fieldLabelled('Enhet'), 'liter');
      await tester.enterText(
        fieldLabelled('Anteckning (valfritt)'),
        'Ekologisk',
      );
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#name], 'Mjölk');
      expect(savedArgs()[#unit], 'liter');
      expect(
        savedArgs()[#note],
        'Ekologisk',
        reason:
            'The note is layered on after basic(), which drops it — the copyWith '
            'that carries it is easy to lose in a refactor.',
      );
      expect(successes, hasLength(1));
      expect(errors, isEmpty);
    });

    testWidgets('an untouched note saves as no note', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Bananer');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#note], isNull);
    });

    // BUT-1873: the dialog used to read a price controller that no input was
    // ever bound to, so the value could only ever be null. The product answer
    // was to delete the read, not to add the missing field — this case pins
    // both halves, and reddens if a price input is put back.
    testWidgets('no price field is offered and no price is saved', (
      tester,
    ) async {
      await openAddDialog(tester);

      expect(
        find.byType(StyledInput),
        findsNWidgets(5),
        reason:
            'Varunamn, Mängd, Enhet, Kategori, Anteckning. A sixth input means '
            'a price field was added back, which the ticket rules out.',
      );

      await tester.enterText(fieldLabelled('Varunamn'), 'Kaffe');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#estimatedPrice], isNull);
    });

    testWidgets('an empty name blocks the save and keeps the dialog open', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(saves, isEmpty);
      expect(find.text('Lägg till vara'), findsOneWidget);
    });

    // BUT-1891: the quantity field filtered the decimal separator out WHILE
    // the user typed, so "1,5" became 15 before any parse ran. Assertions are
    // taken on both the field text and the saved amount — the field half is
    // what the user sees, and the save half is what reaches Firestore; a fix
    // that only normalises at save time still shows a mangled number on screen.
    testWidgets('a comma quantity survives typing and reaches the save', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.enterText(fieldLabelled('Mängd'), '1,5');
      await tester.enterText(fieldLabelled('Enhet'), 'liter');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#amount], 1.5);
    });

    testWidgets('the comma is still in the field after typing it', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Mängd'), '1,5');
      await tester.pump();

      expect(
        textIn(tester, 'Mängd'),
        '1,5',
        reason:
            'before the fix this read "15" — the separator was filtered '
            'out keystroke by keystroke, which is why the comma-to-period parse '
            'in the dialog could never be reached',
      );
    });

    testWidgets(
      'a typed period is shown back as a comma and saved as a decimal',
      (
        tester,
      ) async {
        await openAddDialog(tester);

        await tester.enterText(fieldLabelled('Varunamn'), 'Grädde');
        await tester.enterText(fieldLabelled('Mängd'), '2.5');
        await tester.pump();

        expect(
          textIn(tester, 'Mängd'),
          '2,5',
          reason:
              'the name of this case claims the field shows a comma back, so '
              'the field is asserted here and not only the saved value',
        );

        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle();

        expect(savedArgs()[#amount], 2.5);
      },
    );

    testWidgets('a second separator cannot be typed', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Mängd'), '1,5,5');
      await tester.pump();

      expect(textIn(tester, 'Mängd'), '1,55');
    });

    testWidgets('letters still cannot be typed into the quantity', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Mängd'), '2kg');
      await tester.pump();

      expect(
        textIn(tester, 'Mängd'),
        '2',
        reason:
            'widening the field to a decimal must not widen it to free text',
      );
    });

    testWidgets('an unreadable quantity falls back to one, not to zero', (
      tester,
    ) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Bröd');
      await tester.enterText(fieldLabelled('Mängd'), '');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#amount], 1.0);
    });

    testWidgets('cancel saves nothing', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Ost');
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(saves, isEmpty);
      expect(successes, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('edit item dialog', () {
    UnifiedShoppingItem existing({
      String? note,
      double? estimatedPrice,
      double amount = 2,
    }) => UnifiedShoppingItem(
      id: 'item-1',
      name: 'Mjölk',
      amount: amount,
      unit: 'liter',
      category: ShoppingCategory.dairy,
      note: note,
      estimatedPrice: estimatedPrice,
    );

    testWidgets('the stored values prefill the fields', (tester) async {
      await openEditDialog(tester, existing(note: 'Ekologisk'));

      expect(textIn(tester, 'Varunamn'), 'Mjölk');
      expect(textIn(tester, 'Enhet'), 'liter');
      expect(textIn(tester, 'Anteckning (valfritt)'), 'Ekologisk');
    });

    testWidgets('an edited name and note reach the save', (tester) async {
      await openEditDialog(tester, existing(note: 'Ekologisk'));

      await tester.enterText(fieldLabelled('Varunamn'), 'Havredryck');
      await tester.enterText(
        fieldLabelled('Anteckning (valfritt)'),
        'Osötad',
      );
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#itemId], 'item-1');
      expect(savedArgs()[#name], 'Havredryck');
      expect(savedArgs()[#notes], 'Osötad');
      expect(successes, hasLength(1));
    });

    // BUT-1874, the discriminating case. Emptying the field used to be
    // indistinguishable from not touching it: copyWith reads a null note as
    // "unchanged", and so does every layer under updateItem. Before the fix
    // this saved 'Ekologisk' back.
    testWidgets('an emptied note saves as cleared', (tester) async {
      await openEditDialog(tester, existing(note: 'Ekologisk'));

      await tester.enterText(fieldLabelled('Anteckning (valfritt)'), '');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(
        savedArgs()[#notes],
        isEmpty,
        reason:
            'A cleared note must not travel as null — the update chain reads '
            'null as "leave this field alone" and would write the old note '
            'straight back.',
      );
    });

    testWidgets('a note left alone survives the save', (tester) async {
      await openEditDialog(tester, existing(note: 'Ekologisk'));

      await tester.enterText(fieldLabelled('Varunamn'), 'Mellanmjölk');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(
        savedArgs()[#notes],
        'Ekologisk',
        reason:
            'The clear signal must fire on an EMPTY field only — a fix that '
            'always cleared would satisfy the case above and silently erase '
            'every note.',
      );
    });

    // BUT-1873 on the edit side: dropping the price read must not drop the
    // price. Nothing in the app can type one today, but items carrying one
    // exist in the model and an edit is not a reason to lose it.
    testWidgets('an existing price survives an edit', (tester) async {
      await openEditDialog(tester, existing(estimatedPrice: 12.5));

      await tester.enterText(fieldLabelled('Varunamn'), 'Mellanmjölk');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#estimatedPrice], 12.5);
    });

    // BUT-1891 on the edit side. The field is seeded from the stored amount, so
    // a period spelling there would hand the user a value their own keyboard
    // can no longer produce.
    testWidgets('a stored decimal prefills with a comma', (tester) async {
      await openEditDialog(tester, existing(amount: 1.5));

      expect(textIn(tester, 'Mängd'), '1,5');
    });

    testWidgets('an edited decimal quantity reaches the save', (tester) async {
      await openEditDialog(tester, existing(amount: 2));

      await tester.enterText(fieldLabelled('Mängd'), '0,5');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#quantity], 0.5);
    });

    testWidgets('an emptied quantity keeps the amount the item had', (
      tester,
    ) async {
      await openEditDialog(tester, existing(amount: 2));

      await tester.enterText(fieldLabelled('Mängd'), '');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(
        savedArgs()[#quantity],
        2.0,
        reason:
            'an unreadable field is not an instruction to set the amount '
            'to a default — on edit the honest answer is the stored value',
      );
    });

    testWidgets('an emptied category falls back to other', (tester) async {
      await openEditDialog(tester, existing());

      await tester.enterText(fieldLabelled('Kategori'), '');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], ShoppingCategory.other);
    });
  });
}
