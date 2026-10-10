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
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/shopping_item_dialog_harness.dart';

void main() {
  late MockUnifiedShoppingViewModel viewModel;
  late List<Invocation> saves;
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
    errors = [];

    when(
      () => viewModel.addItemWithId(
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
      return 'new-row-1';
    });
    when(() => viewModel.removeItem(any())).thenAnswer((_) async => true);

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

  Future<void> openAdd(WidgetTester tester) =>
      openAddDialog(tester, viewModel, onError: errors.add);

  Future<void> openEdit(WidgetTester tester, UnifiedShoppingItem item) =>
      openEditDialog(tester, viewModel, item, onError: errors.add);

  group('add item dialog', () {
    testWidgets('name and note reach the save', (tester) async {
      await openAdd(tester);

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
      // P4-U11: add is class 1, so the receipt is the undo snackbar, not a
      // plain confirmation (produktregler.md:131).
      expect(find.text('La till "Mjölk"'), findsOneWidget);
      expect(find.text('Ångra'), findsOneWidget);
      expect(errors, isEmpty);
    });

    // P4-U11: "Ångra" after an add removes exactly the row that was added,
    // by the id the service returned (produktregler.md:131).
    testWidgets('Ångra removes the added row by its id', (tester) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ångra'));
      await tester.pump();

      verify(() => viewModel.removeItem('new-row-1')).called(1);
    });

    testWidgets('a failed add offers no undo', (tester) async {
      when(
        () => viewModel.addItemWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          estimatedPrice: any(named: 'estimatedPrice'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => null);
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(find.text('Ångra'), findsNothing);
      expect(errors, hasLength(1));
      verifyNever(() => viewModel.removeItem(any()));
    });

    testWidgets(
      'a failed add names the item in the error and shows no receipt',
      (
        tester,
      ) async {
        when(
          () => viewModel.addItemWithId(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => null);
        await openAdd(tester);

        await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle();

        expect(errors, ['Kunde inte lägga till Mjölk']);
        expect(find.text('La till "Mjölk"'), findsNothing);
      },
    );

    testWidgets('an add that throws is reported and gives no receipt', (
      tester,
    ) async {
      when(
        () => viewModel.addItemWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          estimatedPrice: any(named: 'estimatedPrice'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => throw Exception('boom'));
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(errors, hasLength(1));
      expect(errors.single, startsWith('Fel vid tillägg:'));
      expect(find.text('La till "Mjölk"'), findsNothing);
      expect(find.text('Ångra'), findsNothing);
    });

    // Typed category beats the suggestion for the same name, so a save that
    // read the suggestion instead of the field would come back 'dairy'.
    testWidgets('the category typed in the field is the one saved', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Kategori'), 'frozen');
      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], 'frozen');
    });

    testWidgets('a suggested category is saved when the user leaves it', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], ShoppingCategory.dairy);
    });

    testWidgets('no category at all saves as other', (tester) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Diskmedel');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], ShoppingCategory.other);
    });

    testWidgets('a new item is saved at the default priority', (tester) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Mjölk');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(
        savedArgs()[#priority],
        3,
        reason: 'the dialog has no priority input, so basic()\'s default is it',
      );
    });

    testWidgets('surrounding whitespace is trimmed from every text field', (
      tester,
    ) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), '  Mjölk  ');
      await tester.enterText(fieldLabelled('Enhet'), ' liter ');
      await tester.enterText(fieldLabelled('Kategori'), ' frozen ');
      await tester.enterText(
        fieldLabelled('Anteckning (valfritt)'),
        '  Ekologisk ',
      );
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#name], 'Mjölk');
      expect(savedArgs()[#unit], 'liter');
      expect(savedArgs()[#category], 'frozen');
      expect(savedArgs()[#note], 'Ekologisk');
    });

    testWidgets('a whitespace-only note saves as no note', (tester) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Bananer');
      await tester.enterText(fieldLabelled('Anteckning (valfritt)'), '   ');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#note], isNull);
    });

    testWidgets('an untouched note saves as no note', (tester) async {
      await openAdd(tester);

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
      await openAdd(tester);

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
      await openAdd(tester);

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
      await openAdd(tester);

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
      await openAdd(tester);

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
        await openAdd(tester);

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
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Mängd'), '1,5,5');
      await tester.pump();

      expect(textIn(tester, 'Mängd'), '1,55');
    });

    testWidgets('letters still cannot be typed into the quantity', (
      tester,
    ) async {
      await openAdd(tester);

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
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Bröd');
      await tester.enterText(fieldLabelled('Mängd'), '');
      await tester.tap(find.text('Lägg till'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#amount], 1.0);
    });

    testWidgets('cancel saves nothing', (tester) async {
      await openAdd(tester);

      await tester.enterText(fieldLabelled('Varunamn'), 'Ost');
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(saves, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('edit item dialog', () {
    UnifiedShoppingItem existing({
      String? note,
      double? estimatedPrice,
      double amount = 2,
      int priority = 3,
    }) => UnifiedShoppingItem(
      id: 'item-1',
      name: 'Mjölk',
      amount: amount,
      unit: 'liter',
      category: ShoppingCategory.dairy,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );

    testWidgets('the stored values prefill the fields', (tester) async {
      await openEdit(tester, existing(note: 'Ekologisk'));

      expect(textIn(tester, 'Varunamn'), 'Mjölk');
      expect(textIn(tester, 'Enhet'), 'liter');
      expect(textIn(tester, 'Anteckning (valfritt)'), 'Ekologisk');
    });

    testWidgets('an edited name and note reach the save', (tester) async {
      await openEdit(tester, existing(note: 'Ekologisk'));

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
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason:
            'update{namn, mängd, enhet, kategori} is class 3: no friction on '
            'success (produktregler.md:133). The row changing is the receipt.',
      );
      expect(errors, isEmpty);
    });

    testWidgets('a failed edit is still said', (tester) async {
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
      ).thenAnswer((_) async => false);
      await openEdit(tester, existing());

      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(errors, hasLength(1), reason: 'class 3 silences success only');
    });

    // BUT-1874, the discriminating case. Emptying the field used to be
    // indistinguishable from not touching it: copyWith reads a null note as
    // "unchanged", and so does every layer under updateItem. Before the fix
    // this saved 'Ekologisk' back.
    testWidgets('an emptied note saves as cleared', (tester) async {
      await openEdit(tester, existing(note: 'Ekologisk'));

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
      await openEdit(tester, existing(note: 'Ekologisk'));

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
      await openEdit(tester, existing(estimatedPrice: 12.5));

      await tester.enterText(fieldLabelled('Varunamn'), 'Mellanmjölk');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#estimatedPrice], 12.5);
    });

    // BUT-1891 on the edit side. The field is seeded from the stored amount, so
    // a period spelling there would hand the user a value their own keyboard
    // can no longer produce.
    testWidgets('a stored decimal prefills with a comma', (tester) async {
      await openEdit(tester, existing(amount: 1.5));

      expect(textIn(tester, 'Mängd'), '1,5');
    });

    testWidgets('an edited decimal quantity reaches the save', (tester) async {
      await openEdit(tester, existing(amount: 2));

      await tester.enterText(fieldLabelled('Mängd'), '0,5');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#quantity], 0.5);
    });

    testWidgets('an emptied quantity keeps the amount the item had', (
      tester,
    ) async {
      await openEdit(tester, existing(amount: 2));

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

    testWidgets('a failed edit names the item in the error', (tester) async {
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
      ).thenAnswer((_) async => false);
      await openEdit(tester, existing());

      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(errors, ['Kunde inte uppdatera Mjölk']);
    });

    testWidgets('an edit that throws is reported', (tester) async {
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
      ).thenAnswer((_) async => throw Exception('boom'));
      await openEdit(tester, existing());

      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(errors, hasLength(1));
      expect(errors.single, startsWith('Fel vid uppdatering:'));
    });

    // BUT-1873 on the edit side: the add dialog pins its input count, and the
    // edit dialog is a separate widget that could grow a price field alone.
    testWidgets('no price field is offered', (tester) async {
      await openEdit(tester, existing(estimatedPrice: 12.5));

      expect(
        find.byType(StyledInput),
        findsNWidgets(5),
        reason: 'Varunamn, Mängd, Enhet, Kategori, Anteckning',
      );
    });

    testWidgets('an edited unit reaches the save', (tester) async {
      await openEdit(tester, existing());

      await tester.enterText(fieldLabelled('Enhet'), 'dl');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#unit], 'dl');
    });

    testWidgets('an edited category reaches the save', (tester) async {
      await openEdit(tester, existing());

      await tester.enterText(fieldLabelled('Kategori'), 'frozen');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], 'frozen');
    });

    testWidgets('the item keeps its priority through an edit', (tester) async {
      await openEdit(tester, existing(priority: 5));

      await tester.enterText(fieldLabelled('Varunamn'), 'Mellanmjölk');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(
        savedArgs()[#priority],
        5,
        reason: 'the dialog offers no priority input; 5 is not the default',
      );
    });

    testWidgets('surrounding whitespace is trimmed on edit', (tester) async {
      await openEdit(tester, existing(note: 'Ekologisk'));

      await tester.enterText(fieldLabelled('Varunamn'), '  Havredryck ');
      await tester.enterText(fieldLabelled('Enhet'), ' dl ');
      await tester.enterText(
        fieldLabelled('Anteckning (valfritt)'),
        ' Osötad ',
      );
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#name], 'Havredryck');
      expect(savedArgs()[#unit], 'dl');
      expect(savedArgs()[#notes], 'Osötad');
    });

    testWidgets('a whitespace-only note is saved as cleared', (tester) async {
      await openEdit(tester, existing(note: 'Ekologisk'));

      await tester.enterText(fieldLabelled('Anteckning (valfritt)'), '   ');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#notes], isEmpty);
    });

    testWidgets('an emptied category falls back to other', (tester) async {
      await openEdit(tester, existing());

      await tester.enterText(fieldLabelled('Kategori'), '');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(savedArgs()[#category], ShoppingCategory.other);
    });
  });
}
