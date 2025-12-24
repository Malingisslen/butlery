// test/widget/common/bottom_action_bar_ultrathink_test.dart
// Comprehensive tests for BottomActionBar using ultrathink methodology
//
// ULTRATHINK ANALYSIS: BottomActionBar widget (31 lines)
// - StatelessWidget with required child parameter (line 8)
// - Container with AppDimensions.spacingL padding (line 18)
// - Theme integration: colorScheme.surface background (line 20), dividerColor top border (line 23)
// - Border configuration: Top-only border with width 1 (lines 21-26)
// - Child delegation: Direct widget passthrough (line 28)
// - Purpose: Consistent bottom action bar styling across views

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/bottom_action_bar.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('BottomActionBar Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
            surface: Colors.white,
          ),
          dividerColor: Colors.grey.shade300,
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with required child parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 10-13 constructor with required child
        const testChild = Text('Action buttons go here');

        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: testChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display the widget and its child
        expect(find.byType(BottomActionBar), findsOneWidget);
        expect(find.text('Action buttons go here'), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should create Container as main wrapper widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 17-29 Container creation
        const testChild = Text('Container wrapper test');

        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: testChild),
        ));

        expect(tester.takeException(), isNull);

        // Should create Container widget as main structure
        expect(find.byType(Container), findsOneWidget);

        // Container should contain the child widget directly
        expect(find.text('Container wrapper test'), findsOneWidget);
        expect(
            find.descendant(
              of: find.byType(Container),
              matching: find.text('Container wrapper test'),
            ),
            findsOneWidget);
      });

      testWidgets('should apply correct Container padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 18 - AppDimensions.spacingL padding
        const testChild = Text('Padding test');

        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: testChild),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));

        // Should use AppDimensions.spacingL for all sides
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should delegate child widget directly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 28 - direct child delegation
        final testChild = ElevatedButton(
          onPressed: () {},
          child: const Text('Test Button'),
        );

        await tester.pumpWidget(createTestWidget(
          BottomActionBar(child: testChild),
        ));

        expect(tester.takeException(), isNull);

        // Should pass through child widget unchanged
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Test Button'), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.child, equals(testChild));
      });
    });

    group('Theme Integration Testing', () {
      testWidgets('should use Theme colorScheme.surface for background',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 20 - Theme.of(context).colorScheme.surface
        const customSurfaceColor = Color(0xFF123456);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red).copyWith(
              surface: customSurfaceColor,
            ),
          ),
          home: Scaffold(
            body: const BottomActionBar(child: Text('Theme surface test')),
          ),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Should use exact theme surface color
        expect(decoration.color, equals(customSurfaceColor));
      });

      testWidgets('should use Theme dividerColor for border',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 23 - Theme.of(context).dividerColor
        const customDividerColor = Color(0xFF789ABC);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            dividerColor: customDividerColor,
          ),
          home: Scaffold(
            body: const BottomActionBar(child: Text('Theme divider test')),
          ),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Should use exact theme divider color
        expect(border.top.color, equals(customDividerColor));
      });

      testWidgets('should work with light theme', (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration with standard light theme
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: const BottomActionBar(child: Text('Light theme test')),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should render without errors using light theme
        expect(find.text('Light theme test'), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Should have valid color values from light theme
        expect(decoration.color, isNotNull);
        expect(decoration.border, isA<Border>());
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration with standard dark theme
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: const BottomActionBar(child: Text('Dark theme test')),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should render without errors using dark theme
        expect(find.text('Dark theme test'), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Should have valid color values from dark theme
        expect(decoration.color, isNotNull);
        expect(decoration.border, isA<Border>());
      });

      testWidgets('should adapt to different theme configurations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test theme adaptation with custom ColorScheme
        final customColorScheme = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.amber.shade50,
        );

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            colorScheme: customColorScheme,
            dividerColor: Colors.orange,
          ),
          home: Scaffold(
            body: const BottomActionBar(child: Text('Custom theme test')),
          ),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Should use custom theme colors
        expect(decoration.color, equals(Colors.amber.shade50));
        expect(border.top.color, equals(Colors.orange));
      });
    });

    group('Border Configuration Testing', () {
      testWidgets('should create top-only border', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 21-26 - Border.top configuration
        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: Text('Border test')),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Should have border only on top side
        expect(border.top, isNot(equals(BorderSide.none)));
        expect(border.left, equals(BorderSide.none));
        expect(border.right, equals(BorderSide.none));
        expect(border.bottom, equals(BorderSide.none));
      });

      testWidgets('should use correct border width',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 24 - width: 1
        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: Text('Border width test')),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Should use width 1 for top border
        expect(border.top.width, equals(1));
      });

      testWidgets('should maintain consistent border styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test border consistency across multiple instances
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              BottomActionBar(child: Text('First bar')),
              BottomActionBar(child: Text('Second bar')),
              BottomActionBar(child: Text('Third bar')),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // All instances should have identical border configuration
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));

        for (final container in containers) {
          final decoration = container.decoration as BoxDecoration;
          final border = decoration.border as Border;

          expect(border.top.width, equals(1));
          expect(border.left, equals(BorderSide.none));
          expect(border.right, equals(BorderSide.none));
          expect(border.bottom, equals(BorderSide.none));
        }
      });
    });

    group('Child Widget Delegation Testing', () {
      testWidgets('should handle Text child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test various child widget types
        const textChild = Text('Text child widget');

        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: textChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display text child correctly
        expect(find.text('Text child widget'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should handle Button child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test button delegation
        final buttonChild = ElevatedButton(
          onPressed: () {},
          child: const Text('Button child'),
        );

        await tester.pumpWidget(createTestWidget(
          BottomActionBar(child: buttonChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display button child correctly
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Button child'), findsOneWidget);
      });

      testWidgets('should handle Row child widgets with multiple buttons',
          (WidgetTester tester) async {
        // ULTRATHINK: Test complex child widget structure
        final rowChild = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Save')),
            OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
            TextButton(onPressed: () {}, child: const Text('Help')),
          ],
        );

        await tester.pumpWidget(createTestWidget(
          BottomActionBar(child: rowChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display all buttons in Row correctly
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Help'), findsOneWidget);
      });

      testWidgets('should handle Column child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test vertical child layout
        final columnChild = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Action Bar Header'),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () {}, child: const Text('Primary Action')),
          ],
        );

        await tester.pumpWidget(createTestWidget(
          BottomActionBar(child: columnChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display column content correctly
        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Action Bar Header'), findsOneWidget);
        expect(find.text('Primary Action'), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('should handle custom widget child',
          (WidgetTester tester) async {
        // ULTRATHINK: Test complex custom widget delegation
        final customChild = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Custom container child'),
        );

        await tester.pumpWidget(createTestWidget(
          BottomActionBar(child: customChild),
        ));

        expect(tester.takeException(), isNull);

        // Should display custom widget correctly
        expect(find.text('Custom container child'), findsOneWidget);
        // Should have nested Container widgets (BottomActionBar's + custom child's)
        expect(find.byType(Container), findsNWidgets(2));
      });
    });

    group('Layout and Context Integration', () {
      testWidgets('should work in Column layout', (WidgetTester tester) async {
        // ULTRATHINK: Test integration in vertical layouts
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              const Expanded(
                child: Center(child: Text('Main content area')),
              ),
              BottomActionBar(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Bottom action'),
                ),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should work correctly in Column layout
        expect(find.text('Main content area'), findsOneWidget);
        expect(find.text('Bottom action'), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);
      });

      testWidgets('should work as Scaffold bottomNavigationBar',
          (WidgetTester tester) async {
        // ULTRATHINK: Test integration as Scaffold bottom element
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('Page content')),
            bottomNavigationBar: BottomActionBar(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Navigation action'),
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should work as bottomNavigationBar replacement
        expect(find.text('Page content'), findsOneWidget);
        expect(find.text('Navigation action'), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);
      });

      testWidgets('should handle constrained width layouts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test behavior under width constraints
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200,
            child: BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () {}, child: const Text('Fit'))),
                ],
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should adapt to constrained width
        expect(find.text('Fit'), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      });

      testWidgets('should work with SafeArea', (WidgetTester tester) async {
        // ULTRATHINK: Test integration with SafeArea
        await tester.pumpWidget(createTestWidget(
          SafeArea(
            child: BottomActionBar(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Safe action'),
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should work within SafeArea
        expect(find.text('Safe action'), findsOneWidget);
        expect(find.byType(SafeArea), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);
      });
    });

    group('AppDimensions Integration Testing', () {
      testWidgets('should use exact AppDimensions.spacingL value',
          (WidgetTester tester) async {
        // ULTRATHINK: Test AppDimensions constant integration
        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: Text('Dimensions test')),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));

        // Should use exact AppDimensions.spacingL value for padding
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should maintain consistent padding across instances',
          (WidgetTester tester) async {
        // ULTRATHINK: Test padding consistency
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              BottomActionBar(child: Text('First')),
              BottomActionBar(child: Text('Second')),
              BottomActionBar(child: Text('Third')),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // All instances should use identical padding
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));

        for (final container in containers) {
          expect(container.padding,
              equals(const EdgeInsets.all(AppDimensions.spacingL)));
        }
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose required parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => const BottomActionBar(child: Text('API test')),
            returnsNormally);

        // Test parameter accessibility
        const widget = BottomActionBar(child: Text('Parameter test'));
        expect(widget, isA<Widget>());
        expect(widget.child, isA<Widget>());
        expect(widget.child, isA<Text>());

        // Verify child widget properties instead of widget equality
        final childText = widget.child as Text;
        expect(childText.data, equals('Parameter test'));
      });

      testWidgets('should return proper Widget type hierarchy',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify return type hierarchy
        const widget = BottomActionBar(child: Text('Type test'));
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<BottomActionBar>());
      });

      testWidgets('should maintain StatelessWidget behavior',
          (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        Widget createSameWidget() =>
            const BottomActionBar(child: Text('Consistency test'));

        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);

        // First build
        expect(find.text('Consistency test'), findsOneWidget);
        final firstContainer = tester.widget<Container>(find.byType(Container));

        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);

        expect(find.text('Consistency test'), findsOneWidget);
        final secondContainer =
            tester.widget<Container>(find.byType(Container));

        // Should have identical styling
        expect(secondContainer.padding, equals(firstContainer.padding));
        expect(secondContainer.decoration, equals(firstContainer.decoration));
      });

      testWidgets('should work with key parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('bottom-action-bar-key');

        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(
            key: testKey,
            child: Text('Key test'),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Key test'), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle SizedBox.shrink() child',
          (WidgetTester tester) async {
        // ULTRATHINK: Test minimal child widget
        await tester.pumpWidget(createTestWidget(
          const BottomActionBar(child: SizedBox.shrink()),
        ));

        expect(tester.takeException(), isNull);

        // Should handle empty child gracefully
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(BottomActionBar), findsOneWidget);
      });

      testWidgets('should handle very wide child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test overflow behavior
        await tester.pumpWidget(createTestWidget(
          BottomActionBar(
            child: SizedBox(
              width: 2000, // Very wide
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Very wide button'),
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle wide child without crashing
        expect(find.text('Very wide button'), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('should handle very tall child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test height overflow behavior
        await tester.pumpWidget(createTestWidget(
          BottomActionBar(
            child: SizedBox(
              height: 500, // Very tall
              child: const Center(child: Text('Tall content')),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle tall child without crashing
        expect(find.text('Tall content'), findsOneWidget);
      });

      testWidgets('should handle nested BottomActionBar widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test nested widget behavior
        await tester.pumpWidget(createTestWidget(
          BottomActionBar(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const BottomActionBar(
                child: Text('Nested bar'),
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle nesting without issues
        expect(find.byType(BottomActionBar), findsNWidgets(2));
        expect(find.text('Nested bar'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should provide consistent action bar styling across views',
          (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - consistent bottom action bar styling
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              const Expanded(child: Text('Recipe Form')),
              BottomActionBar(
                child: Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () {}, child: const Text('Save Draft'))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () {}, child: const Text('Publish'))),
                  ],
                ),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should provide consistent styling for action bars
        expect(find.text('Save Draft'), findsOneWidget);
        expect(find.text('Publish'), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Should have consistent theming
        expect(decoration.color, isNotNull);
        expect(border.top, isNot(equals(BorderSide.none)));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });

      testWidgets('should serve as visual separator from main content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test visual separation purpose
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: Colors.grey.shade50,
                  child: const Center(child: Text('Main Content Area')),
                ),
              ),
              BottomActionBar(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should provide visual separation with top border
        expect(find.text('Main Content Area'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container).last);
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Top border should provide visual separation
        expect(border.top, isNot(equals(BorderSide.none)));
        expect(border.top.width, equals(1));
      });

      testWidgets('should handle real-world action button scenarios',
          (WidgetTester tester) async {
        // ULTRATHINK: Test realistic usage patterns
        await tester.pumpWidget(createTestWidget(
          BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Add Recipe to Menu'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Save for Later'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle complex action button layouts
        expect(find.text('Add Recipe to Menu'), findsOneWidget);
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Save for Later'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNWidgets(2));

        // Should maintain proper styling and layout
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));
      });
    });
  });
}
