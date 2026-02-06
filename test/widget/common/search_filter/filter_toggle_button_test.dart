// test/widget/common/search_filter/filter_toggle_button_test.dart
// Tests for FilterToggleButton - updated for UI Redesign (simplified styling)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/theme/app_colors.dart';
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
        expect(find.byType(Stack), findsAtLeastNWidgets(1));
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
      });

      testWidgets('should use correct icon size',
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

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.size, equals(AppDimensions.iconSizeAction));
      });
    });

    group('Filter State - Hidden', () {
      testWidgets('should display textMedium color when filters hidden',
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

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, AppColors.textMedium);
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
    });

    group('Filter State - Shown', () {
      testWidgets('should display forestGreen color when filters shown',
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

        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, AppColors.forestGreen);
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
        expect(iconButton.tooltip, 'D\u00f6lj filter');
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

        expect(find.byType(Positioned), findsOneWidget);

        // Find the indicator container with rust color
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasRustCircle = containers.any((container) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            return decoration.shape == BoxShape.circle &&
                decoration.color == AppColors.rust;
          }
          return false;
        });
        expect(hasRustCircle, true);
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

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(IconButton)),
        );
        await tester.pump(const Duration(milliseconds: 100));

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

      testWidgets('should use AppColors.forestGreen when shown regardless of theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light().copyWith(
                primary: Colors.purple,
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

        // UI Redesign: uses AppColors directly, not theme colors
        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, AppColors.forestGreen);
      });

      testWidgets('should use AppColors.textMedium when hidden regardless of theme',
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

        // UI Redesign: uses AppColors directly, not theme colors
        final icon = tester.widget<Icon>(find.byIcon(Icons.filter_list));
        expect(icon.color, AppColors.textMedium);
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
                        hintText: 'S\u00f6k recept...',
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
        expect(iconButton.tooltip, 'D\u00f6lj filter');
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
        expect(iconButton.tooltip, 'D\u00f6lj filter');
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
