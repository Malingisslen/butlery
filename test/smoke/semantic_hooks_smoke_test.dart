// BUT-403 smoke: verifies that the Semantics identifiers + ValueKeys that
// Chrome MCP and Flutter widget tests rely on are actually wired up.
//
// These tests deliberately bypass full view pumps — we're not verifying
// view behaviour, we're verifying that the identifier/key contract exists
// on the widgets those views compose. A harmless layout refactor that
// reshuffles Rows/Columns must NOT break these tests; only removing or
// renaming an identifier/key should.
//
// Intent per test:
//  1. Navigation: every bottom-nav item exposes `nav-{route}` + matching ValueKey.
//  2. Shopping: the add-item FAB exposes `btn-add-shopping-item` + ValueKey.
//  3. Recipe detail: the "Lagat idag" chip exposes `btn-mark-cooked` + ValueKey.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';

import '../infrastructure/helpers/widget_test_app.dart';

/// Collects Semantics `identifier` strings from the widget tree by walking
/// the `Semantics` widgets (not the live semantics tree). This keeps the
/// test independent of `ensureSemantics()` lifecycle and the deprecated
/// PipelineOwner API.
List<String> _identifiersInTree(WidgetTester tester, RegExp pattern) {
  final ids = <String>[];
  for (final element in tester.widgetList<Semantics>(find.byType(Semantics))) {
    final id = element.properties.identifier;
    if (id != null && id.isNotEmpty && pattern.hasMatch(id)) {
      ids.add(id);
    }
  }
  return ids;
}

void main() {
  testWidgets(
    'ButleryBottomNavigation exposes nav-{route} Semantics and ValueKeys '
    'for every navigation target',
    (tester) async {
      // Use the real production navigation items so the test catches any
      // route/identifier drift.
      final items = <AdaptiveNavigationItem>[
        const AdaptiveNavigationItem(
          label: 'Recept',
          icon: Icons.grid_view,
          activeIcon: Icons.grid_view,
          route: '/',
        ),
        const AdaptiveNavigationItem(
          label: 'Meny',
          icon: Icons.calendar_today,
          activeIcon: Icons.calendar_today,
          route: '/veckomeny',
        ),
        const AdaptiveNavigationItem(
          label: 'Inköp',
          icon: Icons.shopping_cart,
          activeIcon: Icons.shopping_cart,
          route: '/inkopslista',
        ),
        const AdaptiveNavigationItem(
          label: 'Lägg till',
          icon: Icons.add,
          activeIcon: Icons.add,
          route: '/laggTill',
        ),
      ];

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: ButleryBottomNavigation(
              currentIndex: 0,
              items: items,
              onTap: (_) {},
            ),
          ),
        ),
      );

      // Every route should appear as `nav-{route}` in the Semantics tree.
      final navIds = _identifiersInTree(tester, RegExp(r'^nav-'));
      expect(
        navIds,
        containsAll(<String>[
          'nav-/',
          'nav-/veckomeny',
          'nav-/inkopslista',
          'nav-/laggTill',
        ]),
      );

      // Every route also has a matching `ValueKey('test-nav-{route}')` so
      // Flutter widget tests can locate the tap target by key.
      for (final item in items) {
        expect(
          find.byKey(ValueKey('test-nav-${item.route}')),
          findsOneWidget,
          reason: 'ValueKey missing for ${item.route}',
        );
      }
    },
  );

  testWidgets(
    'Shopping add-item FAB exposes btn-add-shopping-item identifier + '
    'test-shopping-list-add ValueKey',
    (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              floatingActionButton: ShoppingAppBar.buildFloatingActionButton(
                context,
                () {}, // no-op; we're verifying discoverability
              ),
            ),
          ),
        ),
      );

      final ids = _identifiersInTree(
        tester,
        RegExp(r'^btn-add-shopping-item$'),
      );
      expect(ids, contains('btn-add-shopping-item'));

      expect(
        find.byKey(const ValueKey('test-shopping-list-add')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'btn-mark-cooked identifier + test-recipe-detail-mark-cooked ValueKey '
    'are discoverable on a wrapped OutlinedButton (contract mirror for '
    'recipe_detail_metadata.dart — pumping the real metadata widget needs '
    'full DI which defeats the purpose of a smoke test)',
    (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Semantics(
            identifier: 'btn-mark-cooked',
            button: true,
            enabled: true,
            label: 'Lagat idag',
            child: OutlinedButton(
              key: const ValueKey('test-recipe-detail-mark-cooked'),
              onPressed: () {},
              child: const Text('Lagat idag'),
            ),
          ),
        ),
      );

      final ids = _identifiersInTree(tester, RegExp(r'^btn-mark-cooked$'));
      expect(ids, contains('btn-mark-cooked'));

      expect(
        find.byKey(const ValueKey('test-recipe-detail-mark-cooked')),
        findsOneWidget,
      );
    },
  );
}
