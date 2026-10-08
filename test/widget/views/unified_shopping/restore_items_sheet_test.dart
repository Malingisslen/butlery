// BUT-2140: the "Återställ varor" sheet: two groups, a restore button per
// line that calls the view model, and Ångra that reverts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/restore_items_sheet.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockViewModel extends Mock implements UnifiedShoppingViewModel {}

class _FakeSnapshot extends Fake implements ShoppingRowSnapshot {}

Future<void> _openSheet(
  WidgetTester tester,
  UnifiedShoppingViewModel viewModel,
) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScaffold: false,
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => RestoreItemsSheet.show(context, viewModel),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockViewModel viewModel;
  late ShoppingRowSnapshot removed;

  setUpAll(() => registerFallbackValue(_FakeSnapshot()));

  setUp(() {
    viewModel = _MockViewModel();
    final now = DateTime.now();
    removed = ShoppingRowSnapshot(
      id: 'milk',
      name: 'Mjölk',
      amount: 1,
      unit: 'liter',
      category: 'Mejeri',
      at: now.subtract(const Duration(days: 1)),
    );
    final eggs =
        ShoppingListFactory.buildItem(
          id: 'egg',
          name: 'Ägg',
          amount: 6,
          unit: 'st',
        ).withPreviousSnapshot(
          ShoppingRowSnapshot(
            id: 'egg',
            name: 'Ägg',
            amount: 12,
            unit: 'st',
            category: 'Mejeri',
            at: now.subtract(const Duration(days: 3)),
          ),
        );
    when(() => viewModel.activeList).thenReturn(
      ShoppingListFactory.build(
        items: [eggs],
      ).copyWith(recentlyRemoved: [removed]),
    );
    when(
      () => viewModel.restoreRemovedRow(any()),
    ).thenAnswer((_) async => true);
    when(
      () => viewModel.restoreChangedRow(any()),
    ).thenAnswer((_) async => true);
    when(() => viewModel.removeItem(any())).thenAnswer((_) async => true);
  });

  testWidgets('shows Borttagna and Ändrade with the current value', (
    tester,
  ) async {
    await _openSheet(tester, viewModel);

    expect(find.text('Borttagna'), findsOneWidget);
    expect(find.text('Ändrade'), findsOneWidget);
    expect(find.text('Mjölk 1 l'), findsOneWidget);
    expect(find.text('Ägg 12 st (nu: 6 st)'), findsOneWidget);
    expect(find.text('i går'), findsOneWidget);
    expect(find.text('Återställ'), findsNWidgets(2));
  });

  testWidgets('Återställ on a removed row calls the view model', (
    tester,
  ) async {
    await _openSheet(tester, viewModel);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('restore-removed-milk')),
        matching: find.text('Återställ'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => viewModel.restoreRemovedRow(removed)).called(1);
    expect(find.text('Mjölk är tillbaka på listan.'), findsOneWidget);
  });

  testWidgets('Ångra on a restored removed row removes it again', (
    tester,
  ) async {
    await _openSheet(tester, viewModel);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('restore-removed-milk')),
        matching: find.text('Återställ'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => viewModel.removeItem('milk')).called(1);
  });

  testWidgets('Återställ then Ångra on a changed row swaps it twice', (
    tester,
  ) async {
    await _openSheet(tester, viewModel);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('restore-changed-egg')),
        matching: find.text('Återställ'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => viewModel.restoreChangedRow('egg')).called(1);

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    verify(() => viewModel.restoreChangedRow('egg')).called(1);
  });

  testWidgets('a failed restore says so and offers no Ångra', (tester) async {
    when(
      () => viewModel.restoreRemovedRow(any()),
    ).thenAnswer((_) async => false);
    when(() => viewModel.consumeMutationError()).thenReturn(null);
    await _openSheet(tester, viewModel);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('restore-removed-milk')),
        matching: find.text('Återställ'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ångra'), findsNothing);
    expect(find.text('Ett fel uppstod. Försök igen.'), findsOneWidget);
  });
}
