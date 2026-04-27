// test/widget/common/search_filter/quick_filter_chips_test.dart
//
// Tests for QuickFilterChips - new widget from UI Redesign.
// Verifies filter toggling behavior, "Alla" option logic, and default filters.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';

void main() {
  group('QuickFilterChips', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    final defaultOptions = [
      const QuickFilterOption(id: 'favorites', label: 'Favoriter'),
      const QuickFilterOption(id: 'quick', label: 'Under 30 min'),
      const QuickFilterOption(
        id: 'vegetarian',
        label: 'Vegetariskt',
        icon: Icons.eco,
      ),
    ];

    Widget createTestWidget({
      List<QuickFilterOption>? options,
      Set<String> selectedIds = const {},
      required void Function(String) onFilterToggle,
      bool showAllOption = true,
      String allOptionLabel = 'Alla',
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
        home: Scaffold(
          body: QuickFilterChips(
            options: options ?? defaultOptions,
            selectedIds: selectedIds,
            onFilterToggle: onFilterToggle,
            showAllOption: showAllOption,
            allOptionLabel: allOptionLabel,
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('should render all filter options', (tester) async {
        await tester.pumpWidget(
          createTestWidget(onFilterToggle: (_) {}),
        );

        expect(find.text('Alla'), findsOneWidget);
        expect(find.text('Favoriter'), findsOneWidget);
        expect(find.text('Under 30 min'), findsOneWidget);
        expect(find.text('Vegetariskt'), findsOneWidget);
      });

      testWidgets('should render icon when provided', (tester) async {
        await tester.pumpWidget(
          createTestWidget(onFilterToggle: (_) {}),
        );

        // Only vegetarian has an icon
        expect(find.byIcon(Icons.eco), findsOneWidget);
      });

      testWidgets('should use horizontal scroll', (tester) async {
        await tester.pumpWidget(
          createTestWidget(onFilterToggle: (_) {}),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });

    group('Alla (All) Option Behavior', () {
      testWidgets('should show Alla as selected when no filters are active',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            selectedIds: {},
            onFilterToggle: (_) {},
          ),
        );

        // "Alla" is selected when selectedIds is empty
        expect(find.text('Alla'), findsOneWidget);
      });

      testWidgets('should hide Alla when showAllOption is false',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            showAllOption: false,
            onFilterToggle: (_) {},
          ),
        );

        expect(find.text('Alla'), findsNothing);
      });

      testWidgets('should clear all filters when Alla is tapped',
          (tester) async {
        final toggledIds = <String>[];

        await tester.pumpWidget(
          createTestWidget(
            selectedIds: {'favorites', 'quick'},
            onFilterToggle: (id) => toggledIds.add(id),
          ),
        );

        await tester.tap(find.text('Alla'));
        await tester.pump();

        // Tapping "Alla" should toggle off each active filter
        expect(toggledIds, containsAll(['favorites', 'quick']));
      });

      testWidgets('should not trigger callback when Alla is already selected',
          (tester) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            selectedIds: {},
            onFilterToggle: (_) => callbackCalled = true,
          ),
        );

        // "Alla" is selected (no filters active), tapping should be no-op
        await tester.tap(find.text('Alla'));
        await tester.pump();

        expect(callbackCalled, isFalse);
      });

      testWidgets('should use custom allOptionLabel', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            allOptionLabel: 'Alla recept',
            onFilterToggle: (_) {},
          ),
        );

        expect(find.text('Alla recept'), findsOneWidget);
        expect(find.text('Alla'), findsNothing);
      });
    });

    group('Filter Toggle Behavior', () {
      testWidgets('should call onFilterToggle with correct id', (tester) async {
        String? toggledId;

        await tester.pumpWidget(
          createTestWidget(
            onFilterToggle: (id) => toggledId = id,
          ),
        );

        await tester.tap(find.text('Favoriter'));
        await tester.pump();

        expect(toggledId, 'favorites');
      });

      testWidgets('should call onFilterToggle for each filter', (tester) async {
        final toggledIds = <String>[];

        await tester.pumpWidget(
          createTestWidget(
            onFilterToggle: (id) => toggledIds.add(id),
          ),
        );

        await tester.tap(find.text('Favoriter'));
        await tester.pump();
        await tester.tap(find.text('Under 30 min'));
        await tester.pump();
        await tester.tap(find.text('Vegetariskt'));
        await tester.pump();

        expect(toggledIds, ['favorites', 'quick', 'vegetarian']);
      });

      testWidgets('should handle toggling already selected filter',
          (tester) async {
        String? toggledId;

        await tester.pumpWidget(
          createTestWidget(
            selectedIds: {'favorites'},
            onFilterToggle: (id) => toggledId = id,
          ),
        );

        await tester.tap(find.text('Favoriter'));
        await tester.pump();

        expect(toggledId, 'favorites');
      });
    });

    group('Default Recipe Filters', () {
      testWidgets('should provide correct default filter options',
          (tester) async {
        late List<QuickFilterOption> defaults;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                defaults = QuickFilterChips.getDefaultRecipeFilters(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Current default recipe filters (see QuickFilterChips.getDefaultRecipeFilters):
        //   favorites, quick, vegetarian, pantry, ingredient-search
        expect(defaults.length, 5);
        final ids = defaults.map((f) => f.id).toList();
        expect(ids, [
          'favorites',
          'quick',
          'vegetarian',
          'pantry',
          'ingredient-search',
        ]);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty options list', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            options: [],
            onFilterToggle: (_) {},
          ),
        );

        // Should only show "Alla"
        expect(find.text('Alla'), findsOneWidget);
      });

      testWidgets('should handle rapid tapping', (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            onFilterToggle: (_) => tapCount++,
          ),
        );

        await tester.tap(find.text('Favoriter'));
        await tester.tap(find.text('Favoriter'));
        await tester.tap(find.text('Favoriter'));
        await tester.pump();

        expect(tapCount, 3);
      });
    });
  });
}
