import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';
import 'package:butlery/widgets/common/search_filter/search_stats_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('SearchFilterWidget Facade Pattern Tests', () {
    final testActiveTimeFilters = <String>{'< 30 min', '30-60 min'};
    final testActiveMealTypeFilters = <String>{'Middag', 'Lunch'};
    final testActiveRatingFilters = <String>{'4+', '5'};

    Widget createFullModeWidget({
      String searchQuery = '',
      Set<String> activeTimeFilters = const {},
      Set<String> activeMealTypeFilters = const {},
      Set<String> activeRatingFilters = const {},
      bool showFilters = false,
      bool hasActiveFilters = false,
      Function(String)? onSearchChanged,
      Function(String)? onTimeFilterToggle,
      VoidCallback? onToggleFilters,
      VoidCallback? onClearAllFilters,
      int? resultCount,
    }) {
      return createLocalizedTestApp(
        wrapInScrollView: true,
        child: SearchFilterWidget.withFilters(
          searchQuery: searchQuery,
          onSearchChanged: onSearchChanged ?? (query) {},
          activeTimeFilters: activeTimeFilters,
          activeMealTypeFilters: activeMealTypeFilters,
          activeRatingFilters: activeRatingFilters,
          onTimeFilterToggle: onTimeFilterToggle ?? (filter) {},
          onMealTypeFilterToggle: (filter) {},
          onRatingFilterToggle: (filter) {},
          showFilters: showFilters,
          onToggleFilters: onToggleFilters ?? () {},
          hasActiveFilters: hasActiveFilters,
          onClearAllFilters: onClearAllFilters ?? () {},
          resultCount: resultCount,
        ),
      );
    }

    group('Factory Constructor Tests', () {
      testWidgets('searchOnly factory creates correct configuration',
          (WidgetTester tester) async {
        final widget = SearchFilterWidget.searchOnly(
          searchQuery: 'kottbullar',
          onSearchChanged: (query) {},
          searchHint: 'Sok svenska recept...',
          autofocus: true,
        );

        expect(widget.searchQuery, equals('kottbullar'));
        expect(widget.searchHint, equals('Sok svenska recept...'));
        expect(widget.searchOnly, isTrue);
        expect(widget.autofocus, isTrue);
        expect(widget.activeTimeFilters, isNull);
        expect(widget.showFilters, isNull);
      });

      testWidgets('withFilters factory creates correct configuration',
          (WidgetTester tester) async {
        final widget = SearchFilterWidget.withFilters(
          searchQuery: 'mormors recept',
          onSearchChanged: (query) {},
          activeTimeFilters: testActiveTimeFilters,
          activeMealTypeFilters: testActiveMealTypeFilters,
          activeRatingFilters: testActiveRatingFilters,
          onTimeFilterToggle: (filter) {},
          onMealTypeFilterToggle: (filter) {},
          onRatingFilterToggle: (filter) {},
          showFilters: true,
          onToggleFilters: () {},
          hasActiveFilters: true,
          onClearAllFilters: () {},
          resultCount: 42,
        );

        expect(widget.searchQuery, equals('mormors recept'));
        expect(widget.searchOnly, isFalse);
        expect(widget.activeTimeFilters, equals(testActiveTimeFilters));
        expect(widget.activeMealTypeFilters, equals(testActiveMealTypeFilters));
        expect(widget.activeRatingFilters, equals(testActiveRatingFilters));
        expect(widget.showFilters, isTrue);
        expect(widget.hasActiveFilters, isTrue);
        expect(widget.resultCount, equals(42));
      });

      testWidgets('factory constructors handle optional parameters correctly',
          (WidgetTester tester) async {
        // searchHint defaults to null (rendered as context.l10n.searchHint)
        final minimalSearchWidget = SearchFilterWidget.searchOnly(
          searchQuery: '',
          onSearchChanged: (query) {},
        );

        expect(minimalSearchWidget.searchHint, isNull);
        expect(minimalSearchWidget.autofocus, isFalse);
        expect(minimalSearchWidget.showStats, isFalse);
        expect(minimalSearchWidget.resultCount, isNull);

        final minimalFilterWidget = SearchFilterWidget.withFilters(
          searchQuery: '',
          onSearchChanged: (query) {},
          activeTimeFilters: const <String>{},
          activeMealTypeFilters: const <String>{},
          activeRatingFilters: const <String>{},
          onTimeFilterToggle: (filter) {},
          onMealTypeFilterToggle: (filter) {},
          onRatingFilterToggle: (filter) {},
          showFilters: false,
          onToggleFilters: () {},
          hasActiveFilters: false,
          onClearAllFilters: () {},
        );

        expect(minimalFilterWidget.showStats, isTrue);
        expect(minimalFilterWidget.resultCount, isNull);
      });
    });

    group('Search-Only Mode Rendering', () {
      testWidgets('renders only SearchInputWidget in search-only mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: 'pasta',
              onSearchChanged: (query) {},
              searchHint: 'Sok italienska ratter...',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsNothing);
        expect(find.byType(FiltersPanelWidget), findsNothing);
        expect(find.byType(SearchStatsWidget), findsNothing);

        expect(find.text('Sok italienska ratter...'), findsOneWidget);
      });

      testWidgets('handles search input in search-only mode',
          (WidgetTester tester) async {
        String capturedQuery = '';

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: '',
              onSearchChanged: (query) {
                capturedQuery = query;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'fisksoppa');
        await tester.pump();

        expect(capturedQuery, equals('fisksoppa'));
      });

      testWidgets('does not show stats in search-only mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: 'soppa',
              onSearchChanged: (query) {},
              showStats: true,
              resultCount: 15,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsNothing);
      });
    });

    group('Full Mode Component Integration', () {
      testWidgets('renders all components in full mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            searchQuery: 'lax',
            activeTimeFilters: testActiveTimeFilters,
            showFilters: true,
            hasActiveFilters: true,
            resultCount: 8,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(FiltersPanelWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsOneWidget);
      });

      testWidgets('hides filter panel content when showFilters is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: false,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );
        await tester.pumpAndSettle();

        // FiltersPanelWidget is rendered but collapsed (AnimatedSize -> SizedBox.shrink)
        expect(find.byType(FiltersPanelWidget), findsOneWidget);
      });

      testWidgets('shows filter panel when showFilters is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: true,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FiltersPanelWidget), findsOneWidget);
      });

      testWidgets('toggle filters button triggers callback',
          (WidgetTester tester) async {
        bool toggleCalled = false;

        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: false,
            onToggleFilters: () => toggleCalled = true,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FilterToggleButton));
        await tester.pump();

        expect(toggleCalled, isTrue);
      });
    });

    group('State Management and Lifecycle', () {
      testWidgets('manages TextEditingController lifecycle correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: 'initial',
              onSearchChanged: (query) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);

        // Dispose widget by removing it
        await tester.pumpWidget(
          createLocalizedTestApp(child: const SizedBox()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('synchronizes external search query changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: 'pannkakor',
              onSearchChanged: (query) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('pannkakor'), findsOneWidget);

        // Re-render with new query
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: 'vafflor',
              onSearchChanged: (query) {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('vafflor'), findsOneWidget);
      });

      testWidgets('handles rapid search input without issues',
          (WidgetTester tester) async {
        int callbackCount = 0;
        String lastQuery = '';

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: '',
              onSearchChanged: (query) {
                callbackCount++;
                lastQuery = query;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'k');
        await tester.pump(const Duration(milliseconds: 10));

        await tester.enterText(find.byType(TextFormField), 'ko');
        await tester.pump(const Duration(milliseconds: 10));

        await tester.enterText(find.byType(TextFormField), 'kott');
        await tester.pump(const Duration(milliseconds: 10));

        expect(callbackCount, greaterThan(0));
        expect(lastQuery, equals('kott'));
      });
    });

    group('Filter Count Integration', () {
      testWidgets('calculates active filter count correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            activeTimeFilters: {'< 30 min', '30-60 min'},
            activeMealTypeFilters: {'Middag'},
            activeRatingFilters: {'4+', '5'},
            showFilters: true,
            hasActiveFilters: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchFilterWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsOneWidget);
      });

      testWidgets('handles empty filter sets correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            activeTimeFilters: <String>{},
            activeMealTypeFilters: <String>{},
            activeRatingFilters: <String>{},
            showFilters: true,
            hasActiveFilters: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchFilterWidget), findsOneWidget);
      });
    });

    group('Swedish Localization Patterns', () {
      testWidgets('displays Swedish search hints correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: '',
              onSearchChanged: (query) {},
              searchHint: 'Sok recept...',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sok recept...'), findsOneWidget);
      });

      testWidgets('handles Swedish search queries correctly',
          (WidgetTester tester) async {
        const swedishQueries = [
          'kottbullar',
          'fiskgryta',
          'appelpaj',
          'kryddig kyckling',
          'vegetarisk lasagne',
        ];

        for (final query in swedishQueries) {
          String capturedQuery = '';

          await tester.pumpWidget(
            createLocalizedTestApp(
              child: SearchFilterWidget.searchOnly(
                searchQuery: '',
                onSearchChanged: (q) => capturedQuery = q,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextFormField), query);
          await tester.pump();

          expect(capturedQuery, equals(query));
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles filter callbacks gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: true,
            hasActiveFilters: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchFilterWidget), findsOneWidget);
      });

      testWidgets('handles very long search queries',
          (WidgetTester tester) async {
        const longQuery =
            'en mycket lang sokning som innehaller manga svenska ord';
        String capturedQuery = '';

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SearchFilterWidget.searchOnly(
              searchQuery: '',
              onSearchChanged: (query) => capturedQuery = query,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), longQuery);
        await tester.pump();

        expect(capturedQuery, equals(longQuery));
      });

      testWidgets('maintains state consistency during widget updates',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            searchQuery: 'initial',
            activeTimeFilters: testActiveTimeFilters,
            activeMealTypeFilters: testActiveMealTypeFilters,
            activeRatingFilters: testActiveRatingFilters,
            showFilters: false,
            hasActiveFilters: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('initial'), findsOneWidget);
        expect(find.byType(SearchFilterWidget), findsOneWidget);

        // Update widget with new query
        await tester.pumpWidget(
          createFullModeWidget(
            searchQuery: 'updated',
            activeTimeFilters: testActiveTimeFilters,
            activeMealTypeFilters: testActiveMealTypeFilters,
            activeRatingFilters: testActiveRatingFilters,
            showFilters: true,
            hasActiveFilters: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('updated'), findsOneWidget);
      });
    });
  });
}
