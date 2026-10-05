// PQ-17: the shell's navigation. Four destinations in a tab list, Hem · Meny
// · Inköp · Mer, and a separate "Lägg till" outside it
// (tillganglighetshandoff 'Navigation & toppfält'; Komponentark v1:661-667;
// produktregler.md:1052-1058). The plus opens the add sheet (Skarmar v12 del
// 1 #plussheet). From 768 dp wide and 500 dp tall the rail carries the same
// destinations (produktregler.md:1054).

import 'dart:ui' show Tristate;

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';

import '../../../infrastructure/helpers/ink_fill.dart';

final _sv = AppLocalizationsSv();

const _routes = [
  Routes.home,
  Routes.weeklyMenu,
  Routes.shoppingList,
  Routes.more,
];

class _Pushes extends NavigatorObserver {
  final List<String> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) names.add(name);
  }
}

Widget _app({
  required Widget Function(BuildContext) home,
  ThemeData? theme,
  NavigatorObserver? observer,
}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: theme ?? AppTheme.lightTheme,
    navigatorObservers: [?observer],
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('pushed')),
    ),
    home: Builder(builder: home),
  );
}

Widget _bar(BuildContext context, {int? current, ValueChanged<int>? onTap}) {
  return Scaffold(
    body: const SizedBox.expand(),
    bottomNavigationBar: ButleryBottomNavigation(
      currentIndex: current,
      items: ButleryAdaptiveNavigation.getNavigationItems(context),
      onTap: onTap ?? (_) {},
    ),
  );
}

SemanticsNode _node(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder);

/// The plus's own surface, inside its press.
final _plusMaterial = find
    .descendant(
      of: find.byKey(ButleryAddButton.buttonKey),
      matching: find.byType(Material),
    )
    .first;

void main() {
  group('bottom row', () {
    testWidgets('four tabs in the drawn order, keyed by route', (tester) async {
      await tester.pumpWidget(_app(home: (c) => _bar(c, current: 0)));
      for (final route in _routes) {
        expect(find.byKey(ValueKey('test-nav-$route')), findsOneWidget);
      }
      // Capitalised as drawn (Komponentark v1:663-666; NAV-INK); "Meny",
      // not "Veckomeny" (B-17).
      expect(find.text('Hem'), findsOneWidget);
      expect(find.text('Meny'), findsOneWidget);
      expect(find.text('Inköp'), findsOneWidget);
      expect(find.text('Mer'), findsOneWidget);
      expect(find.text('hem'), findsNothing);
      expect(find.text('lägg till'), findsNothing);
      // The order on screen follows the drawing: Hem, Meny, +, Inköp, Mer.
      double x(String route) =>
          tester.getCenter(find.byKey(ValueKey('test-nav-$route'))).dx;
      final plus = tester.getCenter(find.byKey(ButleryAddButton.buttonKey)).dx;
      expect(x(Routes.home), lessThan(x(Routes.weeklyMenu)));
      expect(x(Routes.weeklyMenu), lessThan(plus));
      expect(plus, lessThan(x(Routes.shoppingList)));
      expect(x(Routes.shoppingList), lessThan(x(Routes.more)));
    });

    testWidgets('the tabs are a tab list; the chosen one is exposed as '
        'selected, the others as not selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(home: (c) => _bar(c, current: 2)));

      final tabs = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.tab,
      );
      expect(tabs, findsNWidgets(4));
      final bar = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.tabBar,
      );
      expect(bar, findsOneWidget);
      // The tab list holds the four tabs and nothing else: the plus is not
      // inside it.
      expect(
        find.descendant(
          of: bar,
          matching: find.byKey(ButleryAddButton.buttonKey),
        ),
        findsNothing,
      );

      for (var i = 0; i < _routes.length; i++) {
        final data = _node(
          tester,
          find.byKey(ValueKey('test-nav-${_routes[i]}')),
        ).getSemanticsData();
        expect(
          data.flagsCollection.isSelected,
          i == 2 ? Tristate.isTrue : Tristate.isFalse,
          reason: _routes[i],
        );
      }
      handle.dispose();
    });

    testWidgets('each tab reports its own index', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(_app(home: (c) => _bar(c, onTap: taps.add)));
      for (final route in _routes) {
        await tester.tap(find.byKey(ValueKey('test-nav-$route')));
      }
      expect(taps, [0, 1, 2, 3]);
    });

    testWidgets('the plus is its own button named "Lägg till", 62 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(home: (c) => _bar(c, current: 0)));
      expect(
        tester.getSemantics(find.byKey(ButleryAddButton.buttonKey)),
        matchesSemantics(
          label: _sv.navigationAddAction,
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSize(find.byKey(ButleryAddButton.buttonKey)),
        const Size.square(ButleryAddButton.outerDiameter),
      );
      handle.dispose();
    });

    testWidgets('the plus is saffron with an ink glyph in light and dark', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _app(theme: theme, home: (c) => _bar(c, current: 0)),
        );
        final material = tester.widget<Material>(_plusMaterial);
        // action.primary and text.onActionPrimary are the same in both
        // modes (tokens.json semantic).
        expect(material.color, const Color(0xFFCE7C1E));
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(ButleryAddButton.buttonKey),
            matching: find.byIcon(ButleryIcons.navAdd),
          ),
        );
        expect(icon.color, const Color(0xFF17251D));
      }
    });
  });

  // NAV-INK: one ink bar in both modes (Komponentark v1:662-666; Skarmar
  // v12 etapp 10 #bredskal :72): surface.ink #24382C, the chosen tab in
  // paper #F5F4ED with the saffron plate line, the others
  // (text.secondary dark), and the plus's paper ring seen on ink.
  group('ink bar', () {
    const ink = Color(0xFF24382C);
    const paper = Color(0xFFF5F4ED);
    const sage = Color(0xFFA9B2A0);
    const saffron = Color(0xFFCE7C1E);

    Color? textColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('the bar is ink with paper and sage labels ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(theme: theme, home: (c) => _bar(c, current: 0)),
        );
        final surface = tester.widget<DecoratedBox>(
          find.byKey(ButleryBottomNavigation.inkSurfaceKey),
        );
        expect((surface.decoration as BoxDecoration).color, ink);
        expect(textColor(tester, 'Hem'), paper);
        for (final label in ['Meny', 'Inköp', 'Mer']) {
          expect(textColor(tester, label), sage, reason: label);
        }
        // The plate line under the chosen label.
        final line = tester
            .widgetList<AnimatedContainer>(
              find.descendant(
                of: find.byKey(const ValueKey('test-nav-${Routes.home}')),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .single;
        expect((line.decoration as BoxDecoration?)?.color, saffron);
        // The plus keeps its saffron fill; its ring is paper on ink.
        final plus = tester.widget<Material>(_plusMaterial);
        expect(plus.color, saffron);
        expect((plus.shape! as CircleBorder).side.color, paper);
      });

      testWidgets('the rail is the same ink ($mode)', (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            theme: theme,
            home: (c) => AdaptiveNavigationScaffold(
              currentIndex: 1,
              items: ButleryAdaptiveNavigation.getNavigationItems(c),
              onNavigationChanged: (_) {},
              body: const Text('body'),
            ),
          ),
        );
        final surface = tester.widget<ColoredBox>(
          find.byKey(ButleryNavigationRail.inkSurfaceKey),
        );
        expect(surface.color, ink);
        expect(textColor(tester, 'Meny'), paper);
        for (final label in ['Hem', 'Inköp', 'Mer']) {
          expect(textColor(tester, label), sage, reason: label);
        }
      });
    }
  });

  group('add sheet', () {
    testWidgets('the plus opens the drawn choices', (tester) async {
      await tester.pumpWidget(_app(home: (c) => _bar(c, current: 0)));
      await tester.tap(find.byKey(ButleryAddButton.buttonKey));
      await tester.pumpAndSettle();

      expect(find.byType(ButleryAddSheet), findsOneWidget);
      expect(find.text(_sv.addRecipeTitle), findsOneWidget);
      expect(find.text(_sv.addSheetQuickSaveTitle), findsOneWidget);
      expect(find.text(_sv.addSheetQuickSaveSubtitle), findsOneWidget);
      expect(find.text(_sv.recipeImportLink), findsOneWidget);
      expect(find.text(_sv.recipeWriteManually), findsOneWidget);
      expect(find.text(_sv.recipeFromImage), findsOneWidget);
      expect(find.text(_sv.recipeFromArchive), findsOneWidget);
      expect(find.text(_sv.recipeVoiceImport), findsOneWidget);
    });

    final choices = <String, String>{
      'test-add-sheet-quick-save': Routes.quickCapture,
      'test-add-sheet-btn-import-url': Routes.smartImport,
      'test-add-sheet-btn-write-manually': Routes.manualEntry,
      'test-add-sheet-btn-photo-import': Routes.photoImport,
      'test-add-sheet-btn-archive-import': Routes.importFromArchive,
      'test-add-sheet-btn-voice-import': Routes.voiceImport,
    };
    for (final entry in choices.entries) {
      testWidgets('${entry.key} closes the sheet and opens ${entry.value}', (
        tester,
      ) async {
        final pushes = _Pushes();
        await tester.pumpWidget(
          _app(observer: pushes, home: (c) => _bar(c, current: 0)),
        );
        await tester.tap(find.byKey(ButleryAddButton.buttonKey));
        await tester.pumpAndSettle();
        pushes.names.clear();

        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.tap(find.byKey(ValueKey(entry.key)));
        await tester.pumpAndSettle();

        expect(find.byType(ButleryAddSheet), findsNothing);
        expect(pushes.names, [entry.value]);
      });
    }
  });

  group('detail views', () {
    testWidgets('the shared detail bar has the four tabs, the plus and '
        'nothing selected', (tester) async {
      final pushes = _Pushes();
      await tester.pumpWidget(
        _app(
          observer: pushes,
          home: (c) =>
              Scaffold(bottomNavigationBar: LayoutScaffolds.detailBottomNav(c)),
        ),
      );
      final nav = tester.widget<ButleryBottomNavigation>(
        find.byType(ButleryBottomNavigation),
      );
      expect(nav.items.map((i) => i.route), _routes);
      expect(nav.currentIndex, isNull);
      expect(find.byKey(ButleryAddButton.buttonKey), findsOneWidget);

      pushes.names.clear();
      await tester.tap(find.byKey(const ValueKey('test-nav-${Routes.more}')));
      await tester.pumpAndSettle();
      expect(pushes.names, [Routes.more]);
    });
  });

  group('rail', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          home: (c) => AdaptiveNavigationScaffold(
            currentIndex: 3,
            items: ButleryAdaptiveNavigation.getNavigationItems(c),
            onNavigationChanged: (_) {},
            body: const Text('body'),
          ),
        ),
      );
    }

    testWidgets('from 768 dp wide and 500 dp tall: our rail, same '
        'destinations, the plus on top', (tester) async {
      await pumpAt(tester, const Size(1024, 768));
      expect(find.byType(ButleryNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ButleryBottomNavigation), findsNothing);
      for (final route in _routes) {
        expect(find.byKey(ValueKey('test-rail-$route')), findsOneWidget);
      }
      final plus = tester.getCenter(find.byKey(ButleryAddButton.buttonKey));
      final home = tester.getCenter(
        find.byKey(const ValueKey('test-rail-${Routes.home}')),
      );
      expect(plus.dy, lessThan(home.dy));
    });

    testWidgets('under 500 dp tall the bottom row stays, whatever the width', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1024, 480));
      expect(find.byType(ButleryNavigationRail), findsNothing);
      expect(find.byType(ButleryBottomNavigation), findsOneWidget);
    });

    testWidgets('a phone in landscape under 768 wide keeps the bottom row', (
      tester,
    ) async {
      await pumpAt(tester, const Size(700, 600));
      expect(find.byType(ButleryBottomNavigation), findsOneWidget);
    });

    testWidgets('the rail exposes the chosen tab as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, const Size(1024, 768));
      final data = tester
          .getSemantics(find.byKey(const ValueKey('test-rail-${Routes.more}')))
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });
  });

  test('the shell has four tabs and Mer is the fourth', () {
    expect(LayoutScaffolds.homeTab, 0);
    expect(LayoutScaffolds.menuTab, 1);
    expect(LayoutScaffolds.shoppingTab, 2);
    expect(LayoutScaffolds.moreTab, 3);
  });

  // BUT-2205: the ink fill around the tabs used to sit above the ink layer,
  // so neither the tab's drawn splash nor the rail's press showed.
  testWidgets('a pressed bottom tab is not covered by the ink fill', (
    tester,
  ) async {
    await tester.pumpWidget(_app(home: (c) => _bar(c, current: 0)));
    final tab = find.byKey(ValueKey('test-nav-${_routes.first}'));
    final gesture = await holdPress(tester, tab);
    expect(pressIsCovered(tester, tab), isFalse);
    await gesture.cancel();
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('a pressed rail tab shows the step on ink '
        '(${theme.brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          theme: theme,
          home: (c) => AdaptiveNavigationScaffold(
            currentIndex: 3,
            items: ButleryAdaptiveNavigation.getNavigationItems(c),
            onNavigationChanged: (_) {},
            body: const Text('body'),
          ),
        ),
      );
      final tab = find.byKey(ValueKey('test-rail-${_routes.first}'));
      expect(pressIsCovered(tester, tab), isFalse);
      final gesture = await holdPress(tester, tab);
      expect(
        paintsInkFill(
          tester,
          tab,
          ModeColors.of(theme.brightness).pressedOnInk,
        ),
        isTrue,
      );
      await gesture.cancel();
    });
  }
}
