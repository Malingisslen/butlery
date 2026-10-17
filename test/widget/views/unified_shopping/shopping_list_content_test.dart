// P3-U09: the category-move receipt.
//
// A category move is class 3 (produktregler.md:133): no Ångra. The row leaves
// the user's view, so the receipt 'Flyttade till {kategori}' stays, and a
// snackbar with no possible follow-up action gets `Stäng`
// (content-style-guide.md:96-97), never `OK`. With an action Flutter keeps a
// snackbar until tapped, so the receipt must close on its own, after the app's
// normal snackbar time. Under assistive navigation it stays until Stäng: the
// action is a real focusable target (tillganglighetshandoff:172).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/snackbar_utils.dart'
    show InkSnackBarAction, SnackBarConfig;
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockVm extends Mock implements UnifiedShoppingViewModel {}

Future<void> _showReceipt(
  WidgetTester tester,
  String category, {
  Locale locale = const Locale('sv'),
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      locale: locale,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => ShoppingListContentWidget.showCategoryMoveReceipt(
            context,
            category,
          ),
          child: const Text('move'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('move'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  testWidgets('one receipt names the category and carries Stäng', (
    tester,
  ) async {
    await _showReceipt(tester, ShoppingCategory.dairy);

    expect(find.byType(SnackBar), findsOneWidget);
    final name = ShoppingCategory.displayName(ShoppingCategory.dairy);
    expect(find.text('Flyttade till $name'), findsOneWidget);

    expect(find.byKey(InkSnackBarAction.actionKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(InkSnackBarAction.actionKey),
        matching: find.text('Stäng'),
      ),
      findsOneWidget,
    );
    expect(find.text('OK'), findsNothing);
    expect(find.text('Ångra'), findsNothing);
  });

  testWidgets('the English receipt reads Close', (tester) async {
    await _showReceipt(
      tester,
      ShoppingCategory.dairy,
      locale: const Locale('en'),
    );

    expect(
      find.descendant(
        of: find.byKey(InkSnackBarAction.actionKey),
        matching: find.text('Close'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Moved to'), findsOneWidget);
  });

  testWidgets('it closes on its own, although it has an action', (
    tester,
  ) async {
    await _showReceipt(tester, ShoppingCategory.frozen);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.persist, isFalse);
    expect(snackBar.duration, SnackBarConfig.normalDuration);
    await tester.pump(SnackBarConfig.normalDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('under assistive navigation it stays until Stäng', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _showReceipt(tester, ShoppingCategory.frozen);

    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
    await tester.pump(SnackBarConfig.normalDuration * 3);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Stäng closes it at once', (tester) async {
    await _showReceipt(tester, ShoppingCategory.frozen);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  group('moving through the row menu', () {
    final milk = ShoppingListFactory.buildItem(
      id: 'm1',
      name: 'Mjölk',
      category: ShoppingCategory.dairy,
      addedAt: DateTime(2026, 10, 5, 9),
    );

    _MockVm vmWith({required bool moveSucceeds}) {
      final vm = _MockVm();
      final list = ShoppingListFactory.build(
        id: 'list',
        items: [milk],
        createdAt: milk.addedAt,
        updatedAt: milk.addedAt,
      );
      when(() => vm.isLoading).thenReturn(false);
      when(() => vm.hasError).thenReturn(false);
      when(() => vm.activeList).thenReturn(list);
      when(() => vm.hasItems).thenReturn(true);
      when(() => vm.items).thenReturn([milk]);
      when(
        () => vm.categoryOrder,
      ).thenReturn(ShoppingCategory.defaultStoreOrder);
      when(() => vm.boughtItems).thenReturn(0);
      when(() => vm.canEditActiveList).thenReturn(true);
      when(
        () => vm.moveItemToCategory(any(), any()),
      ).thenAnswer((_) async => moveSucceeds);
      return vm;
    }

    Future<void> moveViaMenu(WidgetTester tester, _MockVm vm) async {
      // Tall enough for the whole category list, so no row sits below the fold.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ShoppingListContentWidget(
            viewModel: vm,
            onItemTap: (_) {},
            onEditItem: (_) {},
            onDeleteItem: (_) {},
            onCreateList: () {},
            onAddItem: () {},
            onClearCompleted: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Fler val för Mjölk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flytta till kategori'));
      await tester.pumpAndSettle();
      final target = find.text(
        ShoppingCategory.displayName(ShoppingCategory.frozen),
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('a move that went through shows the receipt', (tester) async {
      final vm = vmWith(moveSucceeds: true);
      await moveViaMenu(tester, vm);

      verify(
        () => vm.moveItemToCategory('m1', ShoppingCategory.frozen),
      ).called(1);
      final name = ShoppingCategory.displayName(ShoppingCategory.frozen);
      expect(find.text('Flyttade till $name'), findsOneWidget);
    });

    testWidgets('a move that failed shows no receipt', (tester) async {
      final vm = vmWith(moveSucceeds: false);
      await moveViaMenu(tester, vm);

      verify(
        () => vm.moveItemToCategory('m1', ShoppingCategory.frozen),
      ).called(1);
      expect(find.textContaining('Flyttade till'), findsNothing);
    });
  });

  group('the empty list', () {
    testWidgets('"Lägg till vara" in the empty state adds an item', (
      tester,
    ) async {
      final vm = _MockVm();
      when(() => vm.isLoading).thenReturn(false);
      when(() => vm.hasError).thenReturn(false);
      when(() => vm.activeList).thenReturn(
        ShoppingListFactory.build(
          id: 'list',
          items: const [],
          createdAt: DateTime(2026, 10, 5),
          updatedAt: DateTime(2026, 10, 5),
        ),
      );
      when(() => vm.hasItems).thenReturn(false);
      var added = 0;

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ShoppingListContentWidget(
            viewModel: vm,
            onItemTap: (_) {},
            onEditItem: (_) {},
            onDeleteItem: (_) {},
            onCreateList: () {},
            onAddItem: () => added++,
            onClearCompleted: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shopping-empty-add-item')));
      await tester.pump();

      expect(added, 1);
    });
  });
}
