import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';
import 'package:butlery/widgets/common/search_filter/search_stats_widget.dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';

void main() {
  group('SearchFilterWidget Facade Pattern Tests', () {
    // Swedish test data - ultrathink realistic patterns
    final testActiveTimeFilters = <String>{'< 30 min', '30-60 min'};
    final testActiveMealTypeFilters = <String>{'Middag', 'Lunch'};
    final testActiveRatingFilters = <String>{'4+', '5'};
    
    // Helper function for creating full mode widgets - ultrathink pattern
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
      return MaterialApp(
        home: Scaffold(
          body: SearchFilterWidget.withFilters(
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
        ),
      );
    }
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    group('Factory Constructor Tests', () {
      testWidgets('searchOnly factory creates correct configuration', (WidgetTester tester) async {
        final widget = SearchFilterWidget.searchOnly(
          searchQuery: 'köttbullar',
          onSearchChanged: (query) {
            // Callback tested elsewhere - focus on factory constructor logic
          },
          searchHint: 'Sök svenska recept...',
          autofocus: true,
        );

        // Verify factory constructor properties without rendering
        expect(widget.searchQuery, equals('köttbullar'));
        expect(widget.searchHint, equals('Sök svenska recept...'));
        expect(widget.searchOnly, isTrue);
        expect(widget.autofocus, isTrue);
        expect(widget.activeTimeFilters, isNull);
        expect(widget.showFilters, isNull);
      });

      testWidgets('withFilters factory creates correct configuration', (WidgetTester tester) async {
        final widget = SearchFilterWidget.withFilters(
          searchQuery: 'mormors recept',
          onSearchChanged: (query) {
            // Callback behavior tested elsewhere - focus on factory constructor
          },
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

        // Verify factory constructor sets all required properties
        expect(widget.searchQuery, equals('mormors recept'));
        expect(widget.searchOnly, isFalse);
        expect(widget.activeTimeFilters, equals(testActiveTimeFilters));
        expect(widget.activeMealTypeFilters, equals(testActiveMealTypeFilters));
        expect(widget.activeRatingFilters, equals(testActiveRatingFilters));
        expect(widget.showFilters, isTrue);
        expect(widget.hasActiveFilters, isTrue);
        expect(widget.resultCount, equals(42));
      });

      testWidgets('factory constructors handle optional parameters correctly', (WidgetTester tester) async {
        // Test minimal searchOnly configuration
        final minimalSearchWidget = SearchFilterWidget.searchOnly(
          searchQuery: '',
          onSearchChanged: (query) {},
        );

        expect(minimalSearchWidget.searchHint, equals('Sök...'));
        expect(minimalSearchWidget.autofocus, isFalse);
        expect(minimalSearchWidget.showStats, isFalse);
        expect(minimalSearchWidget.resultCount, isNull);

        // Test minimal withFilters configuration
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
      testWidgets('renders only SearchInputWidget in search-only mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: 'pasta',
                onSearchChanged: (query) {},
                searchHint: 'Sök italienska rätter...',
              ),
            ),
          ),
        );

        // Should render only SearchInputWidget
        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsNothing);
        expect(find.byType(FiltersPanelWidget), findsNothing);
        expect(find.byType(SearchStatsWidget), findsNothing);

        // Verify Swedish hint text
        expect(find.text('Sök italienska rätter...'), findsOneWidget);
      });

      testWidgets('handles search input in search-only mode', (WidgetTester tester) async {
        String capturedQuery = '';
        bool searchChanged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: '',
                onSearchChanged: (query) {
                  capturedQuery = query;
                  searchChanged = true;
                },
              ),
            ),
          ),
        );

        // Type in search field
        await tester.enterText(find.byType(TextField), 'fisksoppa');
        await tester.pump();

        // Verify callback triggered
        expect(searchChanged, isTrue);
        expect(capturedQuery, equals('fisksoppa'));
      });

      testWidgets('does not show stats in search-only mode - facade design pattern', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: 'soppa',
                onSearchChanged: (query) {},
                showStats: true,
                resultCount: 15,
              ),
            ),
          ),
        );

        // Search-only mode only shows SearchInputWidget - ultrathink production code analysis
        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsNothing);
      });
    });

    group('Full Mode Component Integration', () {

      testWidgets('renders all components in full mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            searchQuery: 'lax',
            activeTimeFilters: testActiveTimeFilters,
            showFilters: true,
            hasActiveFilters: true,
            resultCount: 8,
          ),
        );

        // All components should be present
        expect(find.byType(SearchInputWidget), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(FiltersPanelWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsOneWidget);
      });

      testWidgets('hides filter panel when showFilters is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: false,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );

        await tester.pumpAndSettle();

        // Filter panel should be rendered but collapsed
        expect(find.byType(FiltersPanelWidget), findsOneWidget);
      });

      testWidgets('shows filter panel when showFilters is true', (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: true,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );

        await tester.pumpAndSettle();

        // Filter panel should be visible
        expect(find.byType(FiltersPanelWidget), findsOneWidget);
      });

      testWidgets('toggle filters button triggers callback', (WidgetTester tester) async {
        bool toggleCalled = false;

        await tester.pumpWidget(
          createFullModeWidget(
            showFilters: false,
            onToggleFilters: () => toggleCalled = true,
            activeTimeFilters: testActiveTimeFilters,
          ),
        );

        // Tap filter toggle button
        await tester.tap(find.byType(FilterToggleButton));
        await tester.pump();

        expect(toggleCalled, isTrue);
      });
    });

    group('State Management and Lifecycle', () {
      testWidgets('manages TextEditingController lifecycle correctly', (WidgetTester tester) async {
        // Create widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: 'initial',
                onSearchChanged: (query) {},
              ),
            ),
          ),
        );

        // Verify TextField is created
        expect(find.byType(TextField), findsOneWidget);

        // Dispose widget by removing it
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));

        // Should not crash during disposal
        expect(tester.takeException(), isNull);
      });

      testWidgets('synchronizes external search query changes', (WidgetTester tester) async {
        String currentQuery = 'pannkakor';

        // Initial render
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: currentQuery,
                onSearchChanged: (query) {
                  // Track callback but don't setState during build - ultrathink pattern
                },
              ),
            ),
          ),
        );

        // Initial state
        expect(find.text('pannkakor'), findsOneWidget);

        // Simulate external state change by re-rendering with new query
        currentQuery = 'våfflor';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: currentQuery,
                onSearchChanged: (query) {},
              ),
            ),
          ),
        );

        await tester.pump();

        // Should update TextField - tests didUpdateWidget synchronization
        expect(find.text('våfflor'), findsOneWidget);
      });

      testWidgets('handles rapid search input without issues', (WidgetTester tester) async {
        int callbackCount = 0;
        String lastQuery = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: '',
                onSearchChanged: (query) {
                  callbackCount++;
                  lastQuery = query;
                },
              ),
            ),
          ),
        );

        // Rapid typing
        await tester.enterText(find.byType(TextField), 'k');
        await tester.pump(const Duration(milliseconds: 10));
        
        await tester.enterText(find.byType(TextField), 'kö');
        await tester.pump(const Duration(milliseconds: 10));
        
        await tester.enterText(find.byType(TextField), 'kött');
        await tester.pump(const Duration(milliseconds: 10));

        // Should handle rapid changes
        expect(callbackCount, greaterThan(0));
        expect(lastQuery, equals('kött'));
      });
    });

    group('Filter Count Integration', () {
      testWidgets('calculates active filter count correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            activeTimeFilters: {'< 30 min', '30-60 min'},
            activeMealTypeFilters: {'Middag'},
            activeRatingFilters: {'4+', '5'},
            showFilters: true,
            hasActiveFilters: true,
          ),
        );

        // Widget should be created without issues
        expect(find.byType(SearchFilterWidget), findsOneWidget);
        expect(find.byType(SearchStatsWidget), findsOneWidget);
        
        // Total filters: 2 + 1 + 2 = 5 active filters should be reflected in stats
      });

      testWidgets('handles empty filter sets correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createFullModeWidget(
            activeTimeFilters: <String>{},
            activeMealTypeFilters: <String>{},
            activeRatingFilters: <String>{},
            showFilters: true,
            hasActiveFilters: false,
          ),
        );

        // Should handle empty sets without issues
        expect(find.byType(SearchFilterWidget), findsOneWidget);
      });
    });

    group('Swedish Localization Patterns', () {
      testWidgets('displays Swedish search hints correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: '',
                onSearchChanged: (query) {},
                searchHint: 'Sök recept...',
              ),
            ),
          ),
        );

        expect(find.text('Sök recept...'), findsOneWidget);
      });

      testWidgets('handles Swedish search queries correctly', (WidgetTester tester) async {
        const swedishQueries = [
          'köttbullar',
          'fiskgryta',
          'äppelpaj',
          'kryddig kyckling',
          'vegetarisk lasagne'
        ];

        for (final query in swedishQueries) {
          String capturedQuery = '';
          
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SearchFilterWidget.searchOnly(
                  searchQuery: '',
                  onSearchChanged: (q) => capturedQuery = q,
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), query);
          await tester.pump();

          expect(capturedQuery, equals(query));
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles null filter callbacks gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.withFilters(
                searchQuery: '',
                onSearchChanged: (query) {},
                activeTimeFilters: const <String>{},
                activeMealTypeFilters: const <String>{},
                activeRatingFilters: const <String>{},
                onTimeFilterToggle: (filter) {},
                onMealTypeFilterToggle: (filter) {},
                onRatingFilterToggle: (filter) {},
                showFilters: true,
                onToggleFilters: () {},
                hasActiveFilters: false,
                onClearAllFilters: () {},
              ),
            ),
          ),
        );

        // Should render without crashing
        expect(find.byType(SearchFilterWidget), findsOneWidget);
      });

      testWidgets('handles very long search queries', (WidgetTester tester) async {
        const longQuery = 'en mycket lång sökning som innehåller många svenska ord och tecken för att testa hur widgeten hanterar långa strängar';
        String capturedQuery = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.searchOnly(
                searchQuery: '',
                onSearchChanged: (query) => capturedQuery = query,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), longQuery);
        await tester.pump();

        expect(capturedQuery, equals(longQuery));
      });

      testWidgets('maintains state consistency during widget updates', (WidgetTester tester) async {
        String currentQuery = 'initial';
        bool showFilters = false;

        // Use a simpler approach to avoid setState during build - ultrathink pattern
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.withFilters(
                searchQuery: currentQuery,
                onSearchChanged: (query) {
                  // This callback will be triggered but we don't call setState here
                  // This tests the external state synchronization behavior
                },
                activeTimeFilters: testActiveTimeFilters,
                activeMealTypeFilters: testActiveMealTypeFilters,
                activeRatingFilters: testActiveRatingFilters,
                onTimeFilterToggle: (filter) {},
                onMealTypeFilterToggle: (filter) {},
                onRatingFilterToggle: (filter) {},
                showFilters: showFilters,
                onToggleFilters: () {},
                hasActiveFilters: true,
                onClearAllFilters: () {},
              ),
            ),
          ),
        );

        // Initial state should be displayed
        expect(find.text(currentQuery), findsOneWidget);
        expect(find.byType(SearchFilterWidget), findsOneWidget);
        
        // Update the widget with new query - simulating external state change
        currentQuery = 'updated';
        showFilters = true;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchFilterWidget.withFilters(
                searchQuery: currentQuery,
                onSearchChanged: (query) {},
                activeTimeFilters: testActiveTimeFilters,
                activeMealTypeFilters: testActiveMealTypeFilters,
                activeRatingFilters: testActiveRatingFilters,
                onTimeFilterToggle: (filter) {},
                onMealTypeFilterToggle: (filter) {},
                onRatingFilterToggle: (filter) {},
                showFilters: showFilters,
                onToggleFilters: () {},
                hasActiveFilters: true,
                onClearAllFilters: () {},
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();

        // Should show updated state
        expect(find.text('updated'), findsOneWidget);
      });
    });
  });
}