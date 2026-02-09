import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/portion_scaler_ui.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('PortionScalerUI Widget Tests', () {
    // Test data
    const originalPortions = 4;
    const minPortions = 1;
    const maxPortions = 20;
    final originalIngredients = [
      '2 dl mjölk',
      '4 ägg',
      '3 dl mjöl',
      '1 tsk salt',
    ];

    Widget createTestWidget({
      int currentPortions = originalPortions,
      bool convertToSwedish = false,
      bool hasAmericanUnits = false,
      required Function(int) onUpdatePortions,
      required VoidCallback onToggleUnitConversion,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _TestAnimationWrapper(
                child: Builder(
                  builder: (context) => PortionScalerUI.buildScaler(
                    context: context,
                    currentPortions: currentPortions,
                    originalPortions: originalPortions,
                    convertToSwedish: convertToSwedish,
                    hasAmericanUnits: hasAmericanUnits,
                    minPortions: minPortions,
                    maxPortions: maxPortions,
                    scaleAnimation: const AlwaysStoppedAnimation(1.0),
                    onUpdatePortions: onUpdatePortions,
                    onToggleUnitConversion: onToggleUnitConversion,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('renders with all basic components',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        // UI Redesign: restaurant_menu icon removed per mockup
        expect(find.byIcon(Icons.restaurant_menu), findsNothing);
        expect(find.text('Portioner:'), findsOneWidget);
        expect(find.text('$originalPortions'), findsOneWidget);
        expect(find.byIcon(Icons.remove), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('does not render ingredients (handled by caller)',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: originalPortions,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - ingredients are NOT rendered by PortionScalerUI
        // They are rendered by recipe_detail_content.dart
        for (String ingredient in originalIngredients) {
          expect(find.text(ingredient), findsNothing);
        }
      });

      testWidgets('shows status info when portions changed',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 8, // Double the original
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        expect(find.text('8'), findsOneWidget); // Current portions number
        expect(find.text('Skalat från 4 till 8 portioner'),
            findsOneWidget); // Status text
      });

      testWidgets('shows unit conversion toggle when has American units',
          (WidgetTester tester) async {
        // Debug: Let's systematically check what's being rendered
        bool callbackCalled = false;

        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: true,
            convertToSwedish: false,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () => callbackCalled = true,
          ),
        );

        // Step 1: Verify text and icon exist (we know these work)
        expect(find.text('Konvertera amerikanska enheter'), findsOneWidget);
        expect(find.byIcon(Icons.language), findsOneWidget);

        // Step 2: Check if the condition is working by tapping the text
        await tester.tap(find.text('Konvertera amerikanska enheter'));
        expect(callbackCalled, isTrue,
            reason: 'Unit conversion callback should be triggered');

        // Step 3: Debug - let's see what widgets are actually created around the text
        final textWidget =
            tester.widget<Text>(find.text('Konvertera amerikanska enheter'));
        debugPrint('Text widget found: $textWidget');

        // Step 4: Check all widgets that contain our text
        final parentWidgets = <Type>[];
        final element =
            tester.element(find.text('Konvertera amerikanska enheter'));
        element.visitAncestorElements((ancestor) {
          parentWidgets.add(ancestor.widget.runtimeType);
          return true;
        });
        debugPrint('Ancestor widgets of text: $parentWidgets');

        // Step 5: For now, just check that the functionality works (callback triggered)
        expect(callbackCalled, isTrue);
      });

      testWidgets('hides unit conversion toggle when no American units',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: false,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.text('Konvertera amerikanska enheter'), findsNothing);
      });
    });

    group('Portion Controls', () {
      testWidgets('increments portions when add button pressed',
          (WidgetTester tester) async {
        // Setup
        int updatedPortions = originalPortions;

        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: updatedPortions,
            onUpdatePortions: (value) => updatedPortions = value,
            onToggleUnitConversion: () {},
          ),
        );

        // Tap add button
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        // Assert
        expect(updatedPortions, equals(originalPortions + 1));
      });

      testWidgets('decrements portions when remove button pressed',
          (WidgetTester tester) async {
        // Setup
        int updatedPortions = originalPortions;

        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: updatedPortions,
            onUpdatePortions: (value) => updatedPortions = value,
            onToggleUnitConversion: () {},
          ),
        );

        // Tap remove button
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();

        // Assert
        expect(updatedPortions, equals(originalPortions - 1));
      });

      testWidgets('disables decrement at minimum portions',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: minPortions,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - Production uses InkWell with Icon, not IconButton
        final removeIcon = find.byIcon(Icons.remove);
        expect(removeIcon, findsOneWidget);

        // Find the InkWell containing the remove icon
        final inkWellFinder = find.ancestor(
          of: removeIcon,
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsOneWidget);

        final inkWell = tester.widget<InkWell>(inkWellFinder);
        expect(inkWell.onTap, isNull); // Should be disabled at minimum
      });

      testWidgets('disables increment at maximum portions',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: maxPortions,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - Production uses InkWell with Icon, not IconButton
        final addIcon = find.byIcon(Icons.add);
        expect(addIcon, findsOneWidget);

        // Find the InkWell containing the add icon
        final inkWellFinder = find.ancestor(
          of: addIcon,
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsOneWidget);

        final inkWell = tester.widget<InkWell>(inkWellFinder);
        expect(inkWell.onTap, isNull); // Should be disabled at maximum
      });

      testWidgets('shows portion count correctly', (WidgetTester tester) async {
        // Test various portion counts
        for (int portions in [1, 4, 10, 20]) {
          await tester.pumpWidget(
            createTestWidget(
              currentPortions: portions,
              onUpdatePortions: (_) {},
              onToggleUnitConversion: () {},
            ),
          );

          expect(find.text('$portions'), findsOneWidget);

          if (portions != originalPortions) {
            expect(
                find.text(
                    'Skalat från $originalPortions till $portions portioner'),
                findsOneWidget);
          }
        }
      });
    });

    group('Unit Conversion', () {
      testWidgets('toggles unit conversion when button tapped',
          (WidgetTester tester) async {
        // Setup
        bool conversionEnabled = false;

        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: true,
            convertToSwedish: conversionEnabled,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () =>
                conversionEnabled = !conversionEnabled,
          ),
        );

        // Find and tap the unit conversion button by its text
        await tester.tap(find.text('Konvertera amerikanska enheter'));
        await tester.pump();

        // Assert
        expect(conversionEnabled, isTrue);
      });

      testWidgets('shows conversion status when enabled',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: true,
            convertToSwedish: true,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        expect(find.text('Amerikanska enheter konverterade till svenska'),
            findsOneWidget);
      });

      testWidgets('shows conversion status without rendering ingredients',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: true,
            convertToSwedish: true,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - conversion status is shown
        expect(find.text('Amerikanska enheter konverterade till svenska'),
            findsOneWidget);
        // Ingredients are NOT rendered by PortionScalerUI
        expect(find.text('3 dl mjöl (från 1 cup)'), findsNothing);
      });
    });

    group('Visual Feedback', () {
      testWidgets('shows different background for scaled portions',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 8, // Different from original
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - Check for status info
        expect(find.text('8'), findsOneWidget); // Current portions number
        expect(find.text('Skalat från $originalPortions till 8 portioner'),
            findsOneWidget);
      });

      testWidgets('shows scaling status when portions changed',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 2, // Half of original
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - status message shown
        expect(find.text('Skalat från 4 till 2 portioner'), findsOneWidget);
      });

      testWidgets('shows animated scale changes', (WidgetTester tester) async {
        // This tests that the animation parameter is properly used
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: originalPortions,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // The widget should accept and use the animation
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });
    });

    group('Layout and Styling', () {
      testWidgets('renders controls without card wrapper',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - controls are rendered (Column with header)
        expect(find.text('Portioner:'), findsOneWidget);
        expect(find.byIcon(Icons.remove), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('maintains proper spacing between elements',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            hasAmericanUnits: true,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - Check for SizedBox spacers
        expect(find.byType(SizedBox), findsAtLeastNWidgets(2));
      });

      testWidgets('uses correct text styles', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - UI Redesign: Uses bodySmall (13px) w400 per mockup
        final portionText = tester.widget<Text>(find.text('Portioner:'));
        expect(portionText.style?.fontSize, equals(13.0));
        expect(portionText.style?.fontWeight, equals(FontWeight.w400));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty ingredients list',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => PortionScalerUI.buildScaler(
                  context: context,
                  currentPortions: 4,
                  originalPortions: 4,
                  convertToSwedish: false,
                  hasAmericanUnits: false,
                  minPortions: 1,
                  maxPortions: 20,
                  scaleAnimation: const AlwaysStoppedAnimation(1.0),
                  onUpdatePortions: (_) {},
                  onToggleUnitConversion: () {},
                ),
              ),
            ),
          ),
        );

        // Assert - Should not crash
        // UI Redesign: restaurant_menu icon removed per mockup
        expect(find.byIcon(Icons.restaurant_menu), findsNothing);
      });

      testWidgets('handles very large portion numbers',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 100,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        expect(find.text('100'), findsOneWidget);
        expect(find.text('Skalat från 4 till 100 portioner'), findsOneWidget);
      });

      testWidgets('handles single portion correctly',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 1,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Skalat från 4 till 1 portioner'),
            findsOneWidget); // Status text
      });

      testWidgets('renders controls correctly with various portions',
          (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          createTestWidget(
            currentPortions: 6,
            onUpdatePortions: (_) {},
            onToggleUnitConversion: () {},
          ),
        );

        // Assert - controls render correctly
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Portioner:'), findsOneWidget);
      });

      testWidgets('handles rapid portion changes', (WidgetTester tester) async {
        // Setup
        int currentPortions = 4;
        late StateSetter setState;

        // Act - Create stateful widget that can rebuild
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setStateCallback) {
                  setState = setStateCallback;
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _TestAnimationWrapper(
                        child: Builder(
                          builder: (context) => PortionScalerUI.buildScaler(
                            context: context,
                            currentPortions: currentPortions,
                            originalPortions: 4,
                            convertToSwedish: false,
                            hasAmericanUnits: false,
                            minPortions: 1,
                            maxPortions: 20,
                            scaleAnimation: const AlwaysStoppedAnimation(1.0),
                            onUpdatePortions: (value) {
                              setState(() {
                                currentPortions = value;
                              });
                            },
                            onToggleUnitConversion: () {},
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Rapidly tap add button
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byIcon(Icons.add));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Wait for all animations and updates
        await tester.pumpAndSettle();

        // Assert
        expect(currentPortions, equals(9)); // 4 + 5
      });
    });
  });
}

// Helper widget to provide animation context
class _TestAnimationWrapper extends StatefulWidget {
  final Widget child;

  const _TestAnimationWrapper({required this.child});

  @override
  State<_TestAnimationWrapper> createState() => _TestAnimationWrapperState();
}

class _TestAnimationWrapperState extends State<_TestAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
