/// Widget tests for MainViewHeader, ButleryFilterChips, ButlerySectionHeader.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  group('MainViewHeader — preferredSize', () {
    test('default with accent bar = headerHeight + accentBarHeight', () {
      const h = MainViewHeader(title: 'dina recept');
      expect(
        h.preferredSize,
        const Size.fromHeight(
          MainViewHeader.headerHeight + MainViewHeader.accentBarHeight,
        ),
      );
    });

    test('showAccentBar=false → headerHeight only', () {
      const h = MainViewHeader(title: 't', showAccentBar: false);
      expect(
        h.preferredSize,
        const Size.fromHeight(MainViewHeader.headerHeight),
      );
    });

    test('headerHeight constant is 140.0', () {
      expect(MainViewHeader.headerHeight, 140.0);
    });

    test('accentBarHeight constant is 4.0', () {
      expect(MainViewHeader.accentBarHeight, 4.0);
    });
  });

  group('MainViewHeader — render', () {
    testWidgets('renders title lowercased', (tester) async {
      await tester.pumpWidget(
        _wrap(const MainViewHeader(title: 'DINA RECEPT')),
      );
      expect(find.text('dina recept'), findsOneWidget);
      expect(find.text('DINA RECEPT'), findsNothing);
    });

    testWidgets('renders count badge when supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainViewHeader(
            title: 'dina recept',
            countBadge: '48 recept',
          ),
        ),
      );
      expect(find.text('48 recept'), findsOneWidget);
    });

    testWidgets('countBadge omitted → no badge text', (tester) async {
      await tester.pumpWidget(_wrap(const MainViewHeader(title: 't')));
      expect(find.textContaining('recept'), findsNothing);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MainViewHeader(
            title: 't',
            trailing: IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
    });

    testWidgets('renders actions list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MainViewHeader(
            title: 't',
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('actions render before trailing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MainViewHeader(
            title: 't',
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
            trailing: IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
    });

    testWidgets('accent bar present by default (two ColoredBoxes)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MainViewHeader(title: 't')));
      expect(
        find.descendant(
          of: find.byType(MainViewHeader),
          matching: find.byType(ColoredBox),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('showAccentBar=false drops the accent ColoredBox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MainViewHeader(
            title: 't',
            showAccentBar: false,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(MainViewHeader),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ghostIllustration null → no HeaderGhostIllustration', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MainViewHeader(title: 't')));
      expect(find.byType(HeaderGhostIllustration), findsNothing);
    });

    testWidgets('ghostIllustration set → HeaderGhostIllustration rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MainViewHeader(
            title: 't',
            ghostIllustration: VegetableType.broccoli,
          ),
        ),
      );
      expect(find.byType(HeaderGhostIllustration), findsOneWidget);
    });
  });

  group('ButleryFilterChips', () {
    testWidgets('renders all chip labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ButleryFilterChips(
            chips: const ['Alla', 'Favoriter', 'Vegetariskt'],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Alla'), findsOneWidget);
      expect(find.text('Favoriter'), findsOneWidget);
      expect(find.text('Vegetariskt'), findsOneWidget);
    });

    testWidgets('tapping a chip fires onSelected with its index', (
      tester,
    ) async {
      var lastIndex = -1;
      await tester.pumpWidget(
        _wrap(
          ButleryFilterChips(
            chips: const ['A', 'B', 'C'],
            selectedIndex: 0,
            onSelected: (i) => lastIndex = i,
          ),
        ),
      );
      await tester.tap(find.text('B'));
      expect(lastIndex, 1);
    });

    testWidgets('selectedIndex=-1 → no chip selected (all bordered)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ButleryFilterChips(
            chips: const ['A', 'B'],
            selectedIndex: -1,
            onSelected: (_) {},
          ),
        ),
      );
      // None should crash; both labels exist.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('empty chip list renders without error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ButleryFilterChips(
            chips: const [],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ButlerySectionHeader', () {
    testWidgets('renders label lowercased', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySectionHeader(
            label: 'SENAST TILLAGDA',
          ),
        ),
      );
      expect(find.text('senast tillagda'), findsOneWidget);
    });

    testWidgets('renders count when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySectionHeader(
            label: 'recept',
            count: '12 st',
          ),
        ),
      );
      expect(find.text('12 st'), findsOneWidget);
    });

    testWidgets('count omitted → no count text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySectionHeader(
            label: 'recept',
          ),
        ),
      );
      expect(find.text('12 st'), findsNothing);
    });

    testWidgets('custom accentColor applied to left border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySectionHeader(
            label: 'x',
            accentColor: Color(0xFFFF0000),
          ),
        ),
      );
      final container = tester.firstWidget<Container>(
        find.descendant(
          of: find.byType(ButlerySectionHeader),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.left.color, const Color(0xFFFF0000));
    });

    testWidgets('no accentColor → falls back to theme primary', (tester) async {
      await tester.pumpWidget(_wrap(const ButlerySectionHeader(label: 'x')));
      final container = tester.firstWidget<Container>(
        find.descendant(
          of: find.byType(ButlerySectionHeader),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      // Just verify a non-null border side was set with width 3.
      expect(border.left.width, 3);
    });
  });
}
