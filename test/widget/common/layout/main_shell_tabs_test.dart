// PQ-17: the shell itself. Four tabs Hem · Meny · Inköp · Mer, deep links
// open the right one, Back from another tab returns to Hem, the keyboard
// shortcuts still switch, and the chosen tab survives state restoration.
//
// The tab views are replaced through LayoutScaffolds.mainMenu(tabBuilder:),
// so the shell is tested without the views' providers.

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = ['tab-hem', 'tab-meny', 'tab-inkop', 'tab-mer'];

Widget _tab(int i) => Center(child: Text(_names[i]));

Widget _shellApp({int initialIndex = 0}) => MaterialApp(
  restorationScopeId: 'app',
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: LayoutScaffolds.mainMenu(
    initialIndex: initialIndex,
    tabBuilder: _tab,
  ),
);

/// The tab the IndexedStack shows.
int _shown(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

/// A phone: the bottom row, not the rail (produktregler.md:1054).
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => mainTabSwitchRequest.value = 0);

  testWidgets('every tab opens its own view', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_shellApp());
    expect(_shown(tester), LayoutScaffolds.homeTab);

    const routes = [
      Routes.home,
      Routes.weeklyMenu,
      Routes.shoppingList,
      Routes.more,
    ];
    for (var i = routes.length - 1; i >= 0; i--) {
      await tester.tap(find.byKey(ValueKey('test-nav-${routes[i]}')));
      await tester.pump();
      expect(_shown(tester), i, reason: routes[i]);
    }
  });

  for (final entry in {
    LayoutScaffolds.homeTab: 'Hem',
    LayoutScaffolds.menuTab: 'Meny',
    LayoutScaffolds.shoppingTab: 'Inköp',
    LayoutScaffolds.moreTab: 'Mer',
  }.entries) {
    testWidgets('a deep link to ${entry.value} opens that tab', (tester) async {
      await tester.pumpWidget(_shellApp(initialIndex: entry.key));
      expect(_shown(tester), entry.key);
    });
  }

  testWidgets('Back from another tab returns to Hem', (tester) async {
    await tester.pumpWidget(_shellApp(initialIndex: LayoutScaffolds.moreTab));
    final popped = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isTrue);
    expect(_shown(tester), LayoutScaffolds.homeTab);
  });

  testWidgets('the keyboard shortcut switches tab', (tester) async {
    await tester.pumpWidget(_shellApp());
    mainTabSwitchRequest.value = LayoutScaffolds.shoppingTab;
    await tester.pump();
    expect(_shown(tester), LayoutScaffolds.shoppingTab);
  });

  testWidgets('the chosen tab survives state restoration', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_shellApp());
    await tester.tap(find.byKey(const ValueKey('test-nav-${Routes.more}')));
    await tester.pump();
    expect(_shown(tester), LayoutScaffolds.moreTab);

    await tester.restartAndRestore();
    expect(_shown(tester), LayoutScaffolds.moreTab);
  });

  testWidgets('the plus is no tab: it leaves the chosen tab as it is', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_shellApp(initialIndex: LayoutScaffolds.menuTab));
    await tester.tap(find.byKey(const ValueKey('test-nav-add')));
    await tester.pumpAndSettle();
    expect(_shown(tester), LayoutScaffolds.menuTab);
  });

  testWidgets('on a tablet the rail switches the same tabs', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_shellApp());
    await tester.tap(find.byKey(const ValueKey('test-rail-${Routes.more}')));
    await tester.pump();
    expect(_shown(tester), LayoutScaffolds.moreTab);
  });
}
