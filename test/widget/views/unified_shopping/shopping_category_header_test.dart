// The shopping list's category heading (Skarmar v12 del 2 #inkop): a
// SectionBand with the name in capitals, "N av M" at the right and a chevron,
// that folds its category.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';

import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../test_support/semantics_announcement.dart';

class _MockVm extends Mock implements UnifiedShoppingViewModel {}

final _addedAt = DateTime(2026, 10, 5, 9);

UnifiedShoppingItem _item(String id, String category, {bool bought = false}) =>
    ShoppingListFactory.buildItem(
      id: id,
      name: 'Vara $id',
      category: category,
      bought: bought,
      addedAt: _addedAt,
    );

_MockVm _vm(List<UnifiedShoppingItem> items) {
  final vm = _MockVm();
  final list = ShoppingListFactory.build(
    id: 'list',
    items: items,
    createdAt: _addedAt,
    updatedAt: _addedAt,
  );
  when(() => vm.isLoading).thenReturn(false);
  when(() => vm.hasError).thenReturn(false);
  when(() => vm.activeList).thenReturn(list);
  when(() => vm.hasItems).thenReturn(items.isNotEmpty);
  when(() => vm.items).thenReturn(items);
  when(() => vm.categoryOrder).thenReturn(ShoppingCategory.defaultStoreOrder);
  when(() => vm.boughtItems).thenReturn(items.where((i) => i.bought).length);
  when(() => vm.canEditActiveList).thenReturn(true);
  return vm;
}

Future<void> _pump(
  WidgetTester tester,
  UnifiedShoppingViewModel vm, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('sv'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ShoppingListContentWidget(
          viewModel: vm,
          onItemTap: (_) {},
          onEditItem: (_) {},
          onDeleteItem: (_) {},
          onCreateList: () {},
          onAddItem: () {},
          onClearCompleted: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _header(String category) =>
    find.byKey(ValueKey('shopping-category-header-$category'));

BoxDecoration _band(WidgetTester tester, String category) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: _header(category),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border is Border,
          ),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  final items = [
    _item('a', ShoppingCategory.fruitVeg),
    _item('b', ShoppingCategory.fruitVeg),
    _item('c', ShoppingCategory.fruitVeg, bought: true),
    _item('d', ShoppingCategory.dairy),
  ];

  testWidgets('the heading is the uppercase name with "N av M" beside it', (
    tester,
  ) async {
    await _pump(tester, _vm(items));

    final name = ShoppingCategory.displayName(ShoppingCategory.fruitVeg);
    final header = _header(ShoppingCategory.fruitVeg);
    expect(
      find.descendant(of: header, matching: find.text(name.toUpperCase())),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('1 av 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _header(ShoppingCategory.dairy),
        matching: find.text('0 av 1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a heading is a toggle that names the category once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _vm(items));

    final heading = find.bySemanticsLabel(RegExp(r', 1 av 3$')).first;
    final lines = announcedLines(tester, heading);
    expect(lines, hasLength(1));
    expect(
      lines.single,
      '${ShoppingCategory.displayName(ShoppingCategory.fruitVeg)}, 1 av 3',
    );
    expectActivatable(tester, heading);
    expectNothingAnnouncedTwice(tester, heading);
    handle.dispose();
  });

  testWidgets('the English count reads "N of M"', (tester) async {
    await _pump(tester, _vm(items), locale: const Locale('en'));

    expect(
      find.descendant(
        of: _header(ShoppingCategory.fruitVeg),
        matching: find.text('1 of 3'),
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: a plated band with an ink bar at its '
        'left edge', (tester) async {
      await _pump(tester, _vm(items), brightness: brightness);

      final cs = brightness == Brightness.dark
          ? AppTheme.darkTheme.colorScheme
          : AppTheme.lightTheme.colorScheme;
      final band = _band(tester, ShoppingCategory.fruitVeg);
      expect(band.color, cs.surfaceContainerHighest);
      final border = band.border! as Border;
      expect(border.left.color, cs.onSurface);
      expect(border.left.width, greaterThan(0));
      expect(border.bottom, BorderSide.none);
    });
  }

  testWidgets('bought items sit flat under one "Köpt (N)" heading', (
    tester,
  ) async {
    await _pump(tester, _vm(items));

    expect(find.text('Köpt (1)'), findsOneWidget);
    expect(find.text('Rensa köpta'), findsOneWidget);
    // The bought row is shown, but not as a folding category of its own.
    expect(find.textContaining('Vara c'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey(
          'shopping-category-header-bought-${ShoppingCategory.fruitVeg}',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('the heading is a full tap target and still collapses', (
    tester,
  ) async {
    await _pump(tester, _vm(items));

    expect(
      tester.getSize(_header(ShoppingCategory.dairy)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.textContaining('Vara d'), findsOneWidget);
    await tester.tap(_header(ShoppingCategory.dairy));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vara d'), findsNothing);
  });
}
