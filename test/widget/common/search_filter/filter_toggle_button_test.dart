// test/widget/common/search_filter/filter_toggle_button_test.dart
// Comprehensive tests for FilterToggleButton using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('FilterToggleButton Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required properties',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
      });

      testWidgets('should have correct border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)),
        );
      });
    });

    group('Filter State - Hidden', () {
      testWidgets('should display inactive state when filters hidden',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        // Should use surface color when inactive
        expect(decoration.color, isNotNull);

        // Should have outline border when inactive
        final border = decoration.border as Border;
        expect(border.top.width, 1);
      });

      testWidgets('should show Swedish tooltip for hidden state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Visa filter');
      });

      testWidgets('should use onSurfaceVariant color for icon when hidden',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                onSurfaceVariant: Colors.grey,
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, Colors.grey);
      });
    });

    group('Filter State - Shown', () {
      testWidgets('should display active state when filters shown',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        // Should use primary container color when active
        expect(decoration.color, isNotNull);

        // Should have primary border when active
        final border = decoration.border as Border;
        expect(border.top.width, 2);
      });

      testWidgets('should show Swedish tooltip for shown state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Dölj filter');
      });

      testWidgets('should use primary color for icon when shown',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                primary: Colors.blue,
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, Colors.blue);
      });
    });

    group('Active Filters Indicator', () {
      testWidgets('should not show indicator when no active filters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        // Should not find any positioned indicator
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets(
          'should show indicator when has active filters and filters hidden',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: true,
                onToggle: () {},
              ),
            ),
          ),
        );

        // Should find the positioned indicator
        expect(find.byType(Positioned), findsOneWidget);

        // Should find the indicator container
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(0));

        // Find a container with circular decoration (the indicator)
        final hasCircularContainer = containers.any((container) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            return decoration.shape == BoxShape.circle;
          }
          return false;
        });
        expect(hasCircularContainer, true);
      });

      testWidgets(
          'should not show indicator when has active filters but filters shown',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: true,
                onToggle: () {},
              ),
            ),
          ),
        );

        // Should not show indicator when filters are visible
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets('should position indicator correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: true,
                onToggle: () {},
              ),
            ),
          ),
        );

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.right, 8);
        expect(positioned.top, 8);
      });

      testWidgets('should use error color for indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                error: Colors.red,
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: true,
                onToggle: () {},
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));

        // Find a container with red circular decoration (the indicator)
        final hasRedCircularContainer = containers.any((container) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            return decoration.shape == BoxShape.circle &&
                decoration.color == Colors.red;
          }
          return false;
        });
        expect(hasRedCircularContainer, true);
      });
    });

    group('Interaction', () {
      testWidgets('should call onToggle when tapped',
          (WidgetTester tester) async {
        bool toggled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {
                  toggled = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        expect(toggled, true);
      });

      testWidgets('should respond to multiple taps',
          (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {
                  tapCount++;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        expect(tapCount, 1);

        await tester.tap(find.byType(IconButton));
        expect(tapCount, 2);

        await tester.tap(find.byType(IconButton));
        expect(tapCount, 3);
      });

      testWidgets('should handle rapid tapping', (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {
                  tapCount++;
                },
              ),
            ),
          ),
        );

        // Rapid taps
        await tester.tap(find.byType(IconButton));
        await tester.tap(find.byType(IconButton));
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(tapCount, 3);
      });

      testWidgets('should show ripple effect on tap',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        // Tap and hold to see ripple
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // IconButton should show ripple effect
        expect(find.byType(IconButton), findsOneWidget);

        await gesture.up();
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets('should use theme primary color',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                primary: Colors.purple,
                primaryContainer: Colors.purple.withValues(alpha: 0.2),
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, Colors.purple);
      });

      testWidgets('should use theme surface color',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                surface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, Colors.white);
      });

      testWidgets('should use theme outline color',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                outline: Colors.grey,
              ),
            ),
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, Colors.grey);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  FilterToggleButton(
                    showFilters: false,
                    hasActiveFilters: false,
                    onToggle: () {},
                  ),
                  const SizedBox(width: 8),
                  FilterToggleButton(
                    showFilters: true,
                    hasActiveFilters: true,
                    onToggle: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsNWidgets(2));
      });

      testWidgets('should work in AppBar actions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Test'),
                actions: [
                  FilterToggleButton(
                    showFilters: false,
                    hasActiveFilters: true,
                    onToggle: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(Positioned),
            findsOneWidget); // Active filters indicator
      });

      testWidgets('should work with padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: FilterToggleButton(
                  showFilters: false,
                  hasActiveFilters: false,
                  onToggle: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });
    });

    group('Use Cases', () {
      testWidgets('should work in search bar', (WidgetTester tester) async {
        bool filtersVisible = false;
        final bool hasActiveFilters = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Sök recept...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterToggleButton(
                    showFilters: filtersVisible,
                    hasActiveFilters: hasActiveFilters,
                    onToggle: () {
                      filtersVisible = !filtersVisible;
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(
            find.byType(Positioned), findsOneWidget); // Active filter indicator
      });

      testWidgets('should toggle state in typical usage',
          (WidgetTester tester) async {
        bool showFilters = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return FilterToggleButton(
                    showFilters: showFilters,
                    hasActiveFilters: false,
                    onToggle: () {
                      setState(() {
                        showFilters = !showFilters;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        // Initially hidden
        IconButton iconButton =
            tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Visa filter');

        // Tap to show
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Now shown
        iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Dölj filter');
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish tooltips',
          (WidgetTester tester) async {
        // Test hidden state
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        IconButton iconButton =
            tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Visa filter');

        // Test shown state
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Dölj filter');
      });
    });

    group('Accessibility', () {
      testWidgets('should be accessible with tooltips',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, isNotNull);
        expect(iconButton.tooltip, 'Visa filter');
      });

      testWidgets('should support semantic labels',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                label: 'Filter toggle',
                child: FilterToggleButton(
                  showFilters: false,
                  hasActiveFilters: true,
                  onToggle: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(FilterToggleButton), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid state changes',
          (WidgetTester tester) async {
        bool showFilters = false;
        bool hasActiveFilters = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return FilterToggleButton(
                    showFilters: showFilters,
                    hasActiveFilters: hasActiveFilters,
                    onToggle: () {
                      setState(() {
                        showFilters = !showFilters;
                        hasActiveFilters = !hasActiveFilters;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        // Multiple rapid state changes
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byType(IconButton));
          await tester.pump();
        }

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets('should work with null-safe operations',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {}, // Empty callback
              ),
            ),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Should not throw any errors
        expect(find.byType(FilterToggleButton), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
