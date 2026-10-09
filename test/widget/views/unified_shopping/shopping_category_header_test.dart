// BUT-2146: the shopping list's category heading (Skarmar v12 del 2 #inkop,
// :881-884 light, :986-989 dark). An uppercase overline over a hairline, with
// "N av M" at the right, and no category-coloured plate behind it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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

BoxDecoration _decoration(WidgetTester tester, String category) {
  final container = tester.widget<AnimatedContainer>(_header(category));
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

    final heading = find.bySemanticsLabel(RegExp(r'^Kategori\n')).first;
    expectActivatable(tester, heading);
    expectNothingAnnouncedTwice(tester, heading);
    handle.dispose();
  });

  testWidgets('the empty-categories toggle says what a tap does, reads its '
      'visible text once, and exposes its toggled state', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _vm(items));

    final toggle = find.bySemanticsLabel(RegExp('^Visa eller dölj'));
    expect(toggle, findsOneWidget);
    final lines = announcedLines(tester, toggle);
    expect(
      lines.where((l) => l == 'Visa eller dölj'),
      hasLength(1),
      reason: '$lines',
    );
    expect(
      lines.where((l) => l == 'Övriga kategorier'),
      hasLength(1),
      reason: 'the visible text is the noun and is read once: $lines',
    );
    expectNothingAnnouncedTwice(tester, toggle);
    expectActivatable(tester, toggle);
    expect(
      tester.getSemantics(toggle).getSemanticsData().flagsCollection.isToggled,
      ui.Tristate.isFalse,
    );

    await tester.tap(find.text('Övriga kategorier'));
    await tester.pump();

    expect(
      tester.getSemantics(toggle).getSemanticsData().flagsCollection.isToggled,
      ui.Tristate.isTrue,
    );
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
    testWidgets('${brightness.name}: no plate, a one-pixel rule in the '
        "facit's colour", (tester) async {
      await _pump(tester, _vm(items), brightness: brightness);

      final cs = brightness == Brightness.dark
          ? AppTheme.darkTheme.colorScheme
          : AppTheme.lightTheme.colorScheme;
      final decoration = _decoration(tester, ShoppingCategory.fruitVeg);
      expect(decoration.color, isNull);
      expect(decoration.borderRadius, isNull);
      final border = decoration.border! as Border;
      expect(border.top, BorderSide.none);
      expect(border.bottom.width, 1);
      // Ink in light (:881), border.control in dark (:986).
      expect(
        border.bottom.color,
        brightness == Brightness.dark ? cs.outline : cs.onSurface,
      );
      expect(cs.onSurface, isNot(cs.outline));
      expect(
        find.descendant(
          of: _header(ShoppingCategory.fruitVeg),
          matching: find.byType(PlateLine),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('a bought section heads with its bare count', (tester) async {
    await _pump(tester, _vm(items));

    final bought = find.byKey(
      ValueKey('shopping-category-header-bought-${ShoppingCategory.fruitVeg}'),
    );
    expect(
      find.descendant(of: bought, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bought, matching: find.textContaining(' av ')),
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
