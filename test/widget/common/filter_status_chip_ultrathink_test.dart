// test/widget/common/filter_status_chip_ultrathink_test.dart
// Comprehensive tests for FilterStatusChip using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: FilterStatusChip widget (65 lines)
// - StatelessWidget with two required parameters: List<String> filterParts, int selectedCount
// - Container with full width styling: themed secondaryContainer color with alpha, border, borderRadius
// - Row structure: Icon (Icons.filter_list) + SizedBox + Expanded Text + Text (count)
// - Complex text logic: 'Filter: ${filterParts.join(' • ')}' - joins parts with bullet separator
// - Swedish localization: '$selectedCount valda' (line 55) for selected count display
// - Theme integration: secondaryContainer colors, onSecondaryContainer text, primary color for count
// - Typography: Two different text styles with different colors and font weights

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/filter_status_chip.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('FilterStatusChip Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            secondary: Colors.blue,
            secondaryContainer: Colors.lightBlue,
            onSecondaryContainer: Color(0xFF0D47A1),
            primary: Colors.green,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with simple filter parts', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 13-17 constructor with required parameters
        const filterParts = ['Category', 'Type'];
        const selectedCount = 3;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display the filter text with bullet separator (line 47)
        expect(find.text('Filter: Category • Type'), findsOneWidget);
        
        // Should display Swedish count text (line 55)
        expect(find.text('3 valda'), findsOneWidget);
        expect(find.byType(FilterStatusChip), findsOneWidget);
      });

      testWidgets('should maintain Container widget structure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 21-36 Container structure
        const filterParts = ['Test'];
        const selectedCount = 1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Container as main structure (line 21)
        expect(find.byType(Container), findsOneWidget);
        
        // Container should have proper styling
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.decoration, isA<BoxDecoration>());
        
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, isA<Color>()); // Should use themed secondaryContainer
        expect(decoration.borderRadius, isA<BorderRadius>());
        expect(decoration.border, isA<Border>());
      });

      testWidgets('should display Row with Icon and Texts', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 37-61 Row structure
        const filterParts = ['Layout', 'Test'];
        const selectedCount = 5;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Row with 4 children: Icon + SizedBox + Expanded + Text (line 37)
        expect(find.byType(Row), findsOneWidget);
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, equals(4));
        expect(row.children[0], isA<Icon>());
        expect(row.children[1], isA<SizedBox>());
        expect(row.children[2], isA<Expanded>());
        expect(row.children[3], isA<Text>());
        
        // Should display filter list icon (line 40)
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
        
        // Should display both filter text and count text
        expect(find.text('Filter: Layout • Test'), findsOneWidget);
        expect(find.text('5 valda'), findsOneWidget);
      });

      testWidgets('should apply correct Container styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 21-36 Container decoration
        const filterParts = ['Styling'];
        const selectedCount = 2;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        final container = tester.widget<Container>(find.byType(Container));
        
        // Should have full width (line 22)
        expect(container.constraints?.minWidth, equals(double.infinity));
        
        // Should have proper padding (lines 23-26)
        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingXs,
        )));
        
        // Should have themed decoration (lines 27-36)
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusS)));
        expect(decoration.border, isA<Border>());
      });
    });

    group('Filter Parts Join Logic and Text Display', () {
      testWidgets('should join single filter part correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 47 with single element
        const filterParts = ['Single'];
        const selectedCount = 1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display single filter part without bullet separator
        expect(find.text('Filter: Single'), findsOneWidget);
        expect(find.text('1 valda'), findsOneWidget);
      });

      testWidgets('should join multiple filter parts with bullet separator', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 47 filterParts.join(' • ')
        const filterParts = ['Category', 'Type', 'Status'];
        const selectedCount = 7;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should join with bullet separator
        expect(find.text('Filter: Category • Type • Status'), findsOneWidget);
        expect(find.text('7 valda'), findsOneWidget);
        
        // Text should contain bullet separators
        final filterText = tester.widget<Text>(find.text('Filter: Category • Type • Status'));
        expect(filterText.data, contains(' • '));
      });

      testWidgets('should handle empty filter parts list', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty filterParts list
        const filterParts = <String>[];
        const selectedCount = 0;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display "Filter: " with empty join result
        expect(find.text('Filter: '), findsOneWidget);
        expect(find.text('0 valda'), findsOneWidget);
      });

      testWidgets('should handle filter parts with special characters', (WidgetTester tester) async {
        // ULTRATHINK: Test complex filter part names
        const filterParts = ['Måltid & Middag', 'Söt/Salt', 'Barn-friendly'];
        const selectedCount = 12;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle Swedish characters and special symbols
        expect(find.text('Filter: Måltid & Middag • Söt/Salt • Barn-friendly'), findsOneWidget);
        expect(find.text('12 valda'), findsOneWidget);
        
        // Should preserve all special characters
        final filterText = tester.widget<Text>(find.text('Filter: Måltid & Middag • Söt/Salt • Barn-friendly'));
        expect(filterText.data, contains('&'));
        expect(filterText.data, contains('/'));
        expect(filterText.data, contains('-'));
        expect(filterText.data, contains('ö'));
        expect(filterText.data, contains('å'));
      });
    });

    group('Swedish Localization and Count Display', () {
      testWidgets('should display Swedish "valda" text for various counts', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 55 Swedish localization
        const filterParts = ['Swedish'];
        
        // Test different count values
        for (final count in [0, 1, 2, 5, 10, 99, 100]) {
          await tester.pumpWidget(createTestWidget(
            FilterStatusChip(
              filterParts: filterParts,
              selectedCount: count,
            ),
          ));

          expect(tester.takeException(), isNull);
          
          // Should always display Swedish "valda" regardless of count
          expect(find.text('$count valda'), findsOneWidget);
          
          // Should not use English pluralization
          expect(find.text('$count selected'), findsNothing);
          expect(find.text('$count items'), findsNothing);
        }
      });

      testWidgets('should handle zero count correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with zero selected items
        const filterParts = ['Zero'];
        const selectedCount = 0;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display "0 valda" not hide or change text
        expect(find.text('0 valda'), findsOneWidget);
        expect(find.text('Filter: Zero'), findsOneWidget);
      });

      testWidgets('should handle large count numbers', (WidgetTester tester) async {
        // ULTRATHINK: Test with very large count numbers
        const filterParts = ['Large'];
        const selectedCount = 9999;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle large numbers correctly
        expect(find.text('9999 valda'), findsOneWidget);
        
        // Text should not cause layout overflow
        expect(find.byType(FilterStatusChip), findsOneWidget);
      });

      testWidgets('should handle negative count gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with negative count
        const filterParts = ['Negative'];
        const selectedCount = -1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display negative count as-is (production code doesn't validate)
        expect(find.text('-1 valda'), findsOneWidget);
      });
    });

    group('Theme Integration and Styling', () {
      testWidgets('should apply correct icon styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 39-43 Icon styling
        const filterParts = ['Icon'];
        const selectedCount = 1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use Icons.filter_list (line 40)
        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.icon, equals(Icons.filter_list));
        
        // Should use AppColors.textMedium (line 41)
        expect(icon.color, equals(AppColors.textMedium));
        
        // Should use correct size (line 42)
        expect(icon.size, equals(AppDimensions.iconSizeM));
      });

      testWidgets('should apply correct text styling for filter text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 46-52 main filter text styling
        const filterParts = ['Style', 'Test'];
        const selectedCount = 3;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create filter text with proper styling
        final filterText = tester.widget<Text>(find.text('Filter: Style • Test'));
        expect(filterText.style, isNotNull);
        
        // Should use AppTextStyles.bodySmall as base (line 48)
        expect(filterText.style!.fontSize, equals(AppTextStyles.bodySmall.fontSize));
        
        // Should use FontWeight.w500 (line 50)
        expect(filterText.style!.fontWeight, equals(FontWeight.w500));
        
        // Should use theme onSecondaryContainer color (line 49)
        expect(filterText.style!.color, equals(const Color(0xFF0D47A1))); // From test theme
      });

      testWidgets('should apply correct text styling for count text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 54-60 count text styling
        const filterParts = ['Count'];
        const selectedCount = 8;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create count text with different styling
        final countText = tester.widget<Text>(find.text('8 valda'));
        expect(countText.style, isNotNull);
        
        // Should use AppTextStyles.bodySmall as base (line 56)
        expect(countText.style!.fontSize, equals(AppTextStyles.bodySmall.fontSize));
        
        // Should use FontWeight.w600 (line 58) - heavier than filter text
        expect(countText.style!.fontWeight, equals(FontWeight.w600));
        
        // Should use theme primary color (line 57)
        expect(countText.style!.color, equals(Colors.green)); // From test theme
      });

      testWidgets('should work with different theme configurations', (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration robustness
        const filterParts = ['Dark', 'Theme'];
        const selectedCount = 4;
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.dark(
                secondary: Colors.orange,
                secondaryContainer: Colors.deepOrange,
                onSecondaryContainer: Colors.white,
                primary: Colors.yellow,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: const FilterStatusChip(
                  filterParts: filterParts,
                  selectedCount: selectedCount,
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // Should adapt colors to dark theme
        final filterText = tester.widget<Text>(find.text('Filter: Dark • Theme'));
        expect(filterText.style!.color, equals(Colors.white)); // Dark theme onSecondaryContainer
        
        final countText = tester.widget<Text>(find.text('4 valda'));
        expect(countText.style!.color, equals(Colors.yellow)); // Dark theme primary
        
        // Icon color should remain AppColors.textMedium (not theme dependent)
        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, equals(AppColors.textMedium));
      });

      testWidgets('should maintain SizedBox spacing in Row structure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 44 SizedBox spacing
        const filterParts = ['Spacing'];
        const selectedCount = 2;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should have proper Row structure with SizedBox spacing
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, equals(4));
        
        // Verify the second child is the spacing SizedBox
        final spacingSizedBox = row.children[1] as SizedBox;
        expect(spacingSizedBox.width, equals(AppDimensions.spacingXs));
        expect(spacingSizedBox.height, isNull); // Should not constrain height
      });
    });

    group('Layout Behavior and Constraints', () {
      testWidgets('should handle very long filter part names with Expanded', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 45-53 Expanded widget behavior
        const filterParts = ['Very Long Filter Name That Could Cause Overflow', 'Another Extremely Long Filter Name'];
        const selectedCount = 15;
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 300, // Constrained width to test Expanded behavior
            child: const FilterStatusChip(
              filterParts: filterParts,
              selectedCount: selectedCount,
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle long text without layout errors using Expanded
        expect(find.byType(Expanded), findsOneWidget);
        expect(find.text('15 valda'), findsOneWidget);
        
        // Should display long text (possibly truncated by Expanded)
        expect(find.textContaining('Very Long Filter Name'), findsOneWidget);
      });

      testWidgets('should maintain full width layout', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 22 double.infinity width
        const filterParts = ['Width'];
        const selectedCount = 1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Container should expand to full available width
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minWidth, equals(double.infinity));
        
        // Should render without layout errors in full width
        expect(find.byType(FilterStatusChip), findsOneWidget);
      });

      testWidgets('should work in constrained containers', (WidgetTester tester) async {
        // ULTRATHINK: Test layout behavior in various container constraints
        const filterParts = ['Constraint'];
        const selectedCount = 6;
        
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              SizedBox(
                width: 200,
                child: FilterStatusChip(
                  filterParts: filterParts,
                  selectedCount: selectedCount,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 400,
                child: FilterStatusChip(
                  filterParts: filterParts,
                  selectedCount: selectedCount,
                ),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should adapt to different container widths without errors
        expect(find.byType(FilterStatusChip), findsNWidgets(2));
        expect(find.text('Filter: Constraint'), findsNWidgets(2));
        expect(find.text('6 valda'), findsNWidgets(2));
      });
    });

    group('Edge Cases and Input Validation', () {
      testWidgets('should handle filter parts with empty strings', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty string in filterParts
        const filterParts = ['', 'Valid', ''];
        const selectedCount = 3;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should join empty strings as-is (production code doesn't filter)
        expect(find.text('Filter:  • Valid • '), findsOneWidget);
        expect(find.text('3 valda'), findsOneWidget);
      });

      testWidgets('should handle filter parts with only whitespace', (WidgetTester tester) async {
        // ULTRATHINK: Test whitespace-only filter parts
        const filterParts = ['   ', 'Normal', '\t\n'];
        const selectedCount = 2;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display whitespace as-is (no trimming in production code)
        expect(find.textContaining('Filter:     • Normal • \t\n'), findsOneWidget);
        expect(find.text('2 valda'), findsOneWidget);
      });

      testWidgets('should cause overflow with very long count text in constrained space', (WidgetTester tester) async {
        // ULTRATHINK: Test actual behavior - long count text does cause layout overflow
        const filterParts = ['Long'];
        const selectedCount = 999999999;
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200, // Constrained to cause count text overflow
            child: const FilterStatusChip(
              filterParts: filterParts,
              selectedCount: selectedCount,
            ),
          ),
        ));

        // Should cause RenderFlex overflow (production code doesn't prevent this)
        final exception = tester.takeException();
        expect(exception, isA<FlutterError>());
        expect(exception.toString(), contains('RenderFlex overflowed'));
        
        // Should still display the count text
        expect(find.text('999999999 valda'), findsOneWidget);
        
        // Should maintain Row layout despite overflow
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose required parameters correctly', (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => const FilterStatusChip(filterParts: [], selectedCount: 0), returnsNormally);
        
        // Test that both parameters are required
        const widget = FilterStatusChip(filterParts: ['Test'], selectedCount: 5);
        expect(widget, isA<Widget>());
        expect(widget.filterParts, equals(['Test']));
        expect(widget.selectedCount, equals(5));
      });

      testWidgets('should return proper Widget type', (WidgetTester tester) async {
        // ULTRATHINK: Verify return type
        const widget = FilterStatusChip(filterParts: ['Type'], selectedCount: 1);
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<FilterStatusChip>());
      });

      testWidgets('should maintain StatelessWidget behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        const filterParts = ['Consistency'];
        const selectedCount = 7;
        Widget createSameWidget() => const FilterStatusChip(filterParts: filterParts, selectedCount: selectedCount);
        
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        // First build
        var filterText = tester.widget<Text>(find.text('Filter: Consistency'));
        var countText = tester.widget<Text>(find.text('7 valda'));
        var icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(filterText.data, equals('Filter: Consistency'));
        expect(countText.data, equals('7 valda'));
        expect(icon.icon, equals(Icons.filter_list));
        
        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        filterText = tester.widget<Text>(find.text('Filter: Consistency'));
        countText = tester.widget<Text>(find.text('7 valda'));
        icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(filterText.data, equals('Filter: Consistency'));
        expect(countText.data, equals('7 valda'));
        expect(icon.icon, equals(Icons.filter_list));
      });

      testWidgets('should work with key parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('filter-status-chip-key');
        const filterParts = ['Key'];
        const selectedCount = 1;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
            key: testKey,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Filter: Key'), findsOneWidget);
        expect(find.text('1 valda'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should create filter status display with clear visual hierarchy', (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - filter status display with visual prominence
        const filterParts = ['Kategori', 'Status', 'Typ'];
        const selectedCount = 12;
        
        await tester.pumpWidget(createTestWidget(
          const FilterStatusChip(
            filterParts: filterParts,
            selectedCount: selectedCount,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create visually distinct container with background and border
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, isNotNull); // Should have background
        expect(decoration.border, isNotNull); // Should have border for visual separation
        
        // Should include filter icon for immediate recognition
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
        
        // Should separate filter description from count with different styling
        final filterText = tester.widget<Text>(find.text('Filter: Kategori • Status • Typ'));
        final countText = tester.widget<Text>(find.text('12 valda'));
        expect(filterText.style!.fontWeight, equals(FontWeight.w500));
        expect(countText.style!.fontWeight, equals(FontWeight.w600)); // Heavier weight
        expect(filterText.style!.color, isNot(equals(countText.style!.color))); // Different colors
      });

      testWidgets('should serve as reusable filter status component', (WidgetTester tester) async {
        // ULTRATHINK: Test reusability intention for various filter scenarios
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              FilterStatusChip(filterParts: ['Recepttyp'], selectedCount: 5),
              SizedBox(height: 8),
              FilterStatusChip(filterParts: ['Måltid', 'Svårighetsgrad'], selectedCount: 12),
              SizedBox(height: 8),
              FilterStatusChip(filterParts: ['Allergier', 'Kost', 'Tid'], selectedCount: 3),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should work as reusable component for different filter combinations
        expect(find.byType(FilterStatusChip), findsNWidgets(3));
        expect(find.text('Filter: Recepttyp'), findsOneWidget);
        expect(find.text('Filter: Måltid • Svårighetsgrad'), findsOneWidget);
        expect(find.text('Filter: Allergier • Kost • Tid'), findsOneWidget);
        
        // Each should display correct Swedish count
        expect(find.text('5 valda'), findsOneWidget);
        expect(find.text('12 valda'), findsOneWidget);
        expect(find.text('3 valda'), findsOneWidget);
        
        // All should maintain consistent styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));
        
        // All should use same layout pattern
        final rows = tester.widgetList<Row>(find.byType(Row));
        expect(rows.length, equals(3));
        for (final row in rows) {
          expect(row.children.length, equals(4)); // Icon + SizedBox + Expanded + Text
        }
      });
    });
  });
}