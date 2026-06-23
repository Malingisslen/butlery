// test/widget/common/search_filter/filter_toggle_button_test.dart
// Tests for FilterToggleButton - updated for UI Redesign (Icons.tune, l10n tooltips)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/l10n/app_localizations.dart';

/// Helper to create a localized MaterialApp for FilterToggleButton tests.
/// Production code uses context.l10n for tooltips, so localization is required.
/// Uses AppTheme.lightTheme by default so cs.primary == AppColors.forestGreen.
Widget _buildApp({
  required Widget home,
  ThemeData? theme,
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
    home: home,
  );
}

void main() {
  group('FilterToggleButton Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required properties', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(Stack), findsAtLeastNWidgets(1));
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
      });

      testWidgets('should use correct icon size', (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
        expect(icon.size, equals(AppDimensions.iconSizeAction));
      });
    });

    group('Filter State - Hidden', () {
      testWidgets('should display textMedium color when filters hidden', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
        expect(icon.color, AppColors.textMedium);
      });

      testWidgets('should show Swedish tooltip for hidden state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Visa filter');
      });
    });

    group('Filter State - Shown', () {
      testWidgets('should display forestGreen color when filters shown', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
        expect(icon.color, AppColors.forestGreen);
      });

      testWidgets('should show Swedish tooltip for shown state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'D\u00f6lj filter');
      });
    });

    group('Active Filters Indicator', () {
      // Scope Positioned search to within FilterToggleButton to avoid
      // picking up Positioned widgets from the theme's badge/tooltip layers.
      Finder findIndicator() => find.descendant(
        of: find.byType(FilterToggleButton),
        matching: find.byType(Positioned),
      );

      testWidgets('should not show indicator when no active filters', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(findIndicator(), findsNothing);
      });

      testWidgets(
        'should show indicator when has active filters and filters hidden',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _buildApp(
              home: Scaffold(
                body: FilterToggleButton(
                  showFilters: false,
                  hasActiveFilters: true,
                  onToggle: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(findIndicator(), findsOneWidget);

          // Find the indicator container with secondary (rust) color from theme
          final containers = tester.widgetList<Container>(
            find.descendant(
              of: find.byType(FilterToggleButton),
              matching: find.byType(Container),
            ),
          );
          final hasCircleIndicator = containers.any((container) {
            if (container.decoration is BoxDecoration) {
              final decoration = container.decoration as BoxDecoration;
              return decoration.shape == BoxShape.circle;
            }
            return false;
          });
          expect(hasCircleIndicator, true);
        },
      );

      testWidgets(
        'should not show indicator when has active filters but filters shown',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _buildApp(
              home: Scaffold(
                body: FilterToggleButton(
                  showFilters: true,
                  hasActiveFilters: true,
                  onToggle: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(findIndicator(), findsNothing);
        },
      );

      testWidgets('should position indicator correctly', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: true,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final positioned = tester.widget<Positioned>(findIndicator());
        expect(positioned.right, 8);
        expect(positioned.top, 8);
      });
    });

    group('Interaction', () {
      testWidgets('should call onToggle when tapped', (
        WidgetTester tester,
      ) async {
        bool toggled = false;

        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        await tester.tap(find.byType(IconButton));
        expect(toggled, true);
      });

      testWidgets('should respond to multiple taps', (
        WidgetTester tester,
      ) async {
        int tapCount = 0;

        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

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
          _buildApp(
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
        await tester.pumpAndSettle();

        await tester.tap(find.byType(IconButton));
        await tester.tap(find.byType(IconButton));
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(tapCount, 3);
      });

      testWidgets('should show ripple effect on tap', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets(
        'should use theme primary color when shown with custom theme',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _buildApp(
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
          await tester.pumpAndSettle();

          // Widget uses cs.primary from the theme
          final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
          expect(icon.color, Colors.purple);
        },
      );

      testWidgets(
        'should use theme onSurfaceVariant when hidden with custom theme',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _buildApp(
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
          await tester.pumpAndSettle();

          // Widget uses cs.onSurfaceVariant from the theme
          final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
          expect(icon.color, Colors.grey);
        },
      );
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsNWidgets(2));
      });

      testWidgets('should work in AppBar actions', (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FilterToggleButton),
            matching: find.byType(Positioned),
          ),
          findsOneWidget,
        ); // Active filters indicator
      });

      testWidgets('should work with padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });
    });

    group('Use Cases', () {
      testWidgets('should work in search bar', (WidgetTester tester) async {
        bool filtersVisible = false;
        final bool hasActiveFilters = true;

        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(FilterToggleButton), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FilterToggleButton),
            matching: find.byType(Positioned),
          ),
          findsOneWidget,
        ); // Active filter indicator
      });

      testWidgets('should toggle state in typical usage', (
        WidgetTester tester,
      ) async {
        bool showFilters = false;

        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        // Initially hidden
        IconButton iconButton = tester.widget<IconButton>(
          find.byType(IconButton),
        );
        expect(iconButton.tooltip, 'Visa filter');

        // Tap to show
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        // Now shown
        iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'D\u00f6lj filter');
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish tooltips', (
        WidgetTester tester,
      ) async {
        // Test hidden state
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        IconButton iconButton = tester.widget<IconButton>(
          find.byType(IconButton),
        );
        expect(iconButton.tooltip, 'Visa filter');

        // Test shown state
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: true,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'D\u00f6lj filter');
      });
    });

    group('Accessibility', () {
      testWidgets('should be accessible with tooltips', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, isNotNull);
        expect(iconButton.tooltip, 'Visa filter');
      });

      testWidgets('should support semantic labels', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(FilterToggleButton), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid state changes', (
        WidgetTester tester,
      ) async {
        bool showFilters = false;
        bool hasActiveFilters = false;

        await tester.pumpWidget(
          _buildApp(
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
        await tester.pumpAndSettle();

        // Multiple rapid state changes
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byType(IconButton));
          await tester.pump();
        }

        expect(find.byType(FilterToggleButton), findsOneWidget);
      });

      testWidgets('should work with null-safe operations', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            home: Scaffold(
              body: FilterToggleButton(
                showFilters: false,
                hasActiveFilters: false,
                onToggle: () {}, // Empty callback
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

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
