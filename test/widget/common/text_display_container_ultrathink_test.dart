// test/widget/common/text_display_container_ultrathink_test.dart
// Comprehensive tests for TextDisplayContainer using ultrathink methodology
//
// ULTRATHINK ANALYSIS: TextDisplayContainer widget (47 lines)
// - StatelessWidget with String text (required), bool expanded (default false), bool scrollable (default true)
// - Container with full width styling: AppColors.backgroundTint, border, AppDimensions constants
// - Text widget with theme integration using Theme.of(context).textTheme.bodyMedium
// - Conditional wrapping logic: SingleChildScrollView if scrollable, Expanded if expanded
// - Widget hierarchy varies based on boolean parameters: content → [SingleChildScrollView?] → [Expanded?]
// - Complex conditional widget building pattern perfect for testing widget composition

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/text_display_container.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('TextDisplayContainer Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 16.0, color: Colors.black87),
          ),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 13-18 constructor with defaults
        const testText = 'Default parameters test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        // Should display the text
        expect(find.text('Default parameters test'), findsOneWidget);
        expect(find.byType(TextDisplayContainer), findsOneWidget);

        // Should use default values: expanded=false, scrollable=true
        expect(find.byType(SingleChildScrollView),
            findsOneWidget); // scrollable=true
        expect(find.byType(Expanded), findsNothing); // expanded=false
      });

      testWidgets('should create Container as main content widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 22-35 Container creation
        const testText = 'Container test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        // Should create Container widget
        expect(find.byType(Container), findsOneWidget);

        // Container should contain Text widget
        expect(find.text('Container test'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should apply correct Container styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 22-30 Container decoration
        const testText = 'Styling test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));

        // Should have correct padding (line 24)
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));

        // Should have correct margin (line 25)
        expect(
            container.margin,
            equals(
                const EdgeInsets.symmetric(vertical: AppDimensions.spacingS)));

        // Should have proper decoration
        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundTint));
        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
        expect(decoration.border, equals(Border.all(color: AppColors.divider)));
      });

      testWidgets('should apply theme text styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 31-34 Text widget with theme styling
        const testText = 'Theme styling test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        final textWidget = tester.widget<Text>(find.text('Theme styling test'));
        expect(textWidget.data, equals('Theme styling test'));

        // Should use theme bodyMedium style
        expect(textWidget.style, isNotNull);
        expect(textWidget.style!.fontSize, equals(16.0)); // From test theme
        expect(
            textWidget.style!.color, equals(Colors.black87)); // From test theme
      });
    });

    group('Text Parameter Testing', () {
      testWidgets('should handle various text content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test different text content types
        final textContents = [
          'Simple text',
          'Multi-line\ntext\ncontent',
          'Long text that might need scrolling: ${'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 10}',
          'Swedish text: Åtgärder för användare med åäö',
          'Text with emoji: Hello world! 🌍',
          '', // Empty text
          '   ', // Whitespace only
        ];

        for (final textContent in textContents) {
          await tester.pumpWidget(createTestWidget(
            TextDisplayContainer(text: textContent),
          ));

          expect(tester.takeException(), isNull);

          // Should display any text content
          expect(find.text(textContent), findsOneWidget);
          expect(find.byType(TextDisplayContainer), findsOneWidget);
        }
      });

      testWidgets('should handle extremely long text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test very long text handling
        final longText = 'Very long text content. ' * 200; // 5000+ characters

        await tester.pumpWidget(createTestWidget(
          TextDisplayContainer(text: longText),
        ));

        expect(tester.takeException(), isNull);

        // Should handle long text without issues
        expect(find.text(longText), findsOneWidget);
        expect(find.byType(SingleChildScrollView),
            findsOneWidget); // Default scrollable=true
      });
    });

    group('Scrollable Parameter Testing', () {
      testWidgets(
          'should wrap in SingleChildScrollView when scrollable=true (default)',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 37-39 scrollable wrapping
        const testText = 'Scrollable true test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            text: testText,
            scrollable: true,
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should wrap in SingleChildScrollView
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        // SingleChildScrollView should contain the Container
        expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Container),
            ),
            findsOneWidget);

        expect(find.text('Scrollable true test'), findsOneWidget);
      });

      testWidgets(
          'should not wrap in SingleChildScrollView when scrollable=false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code condition - no wrapping when scrollable=false
        const testText = 'Scrollable false test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            text: testText,
            scrollable: false,
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should not wrap in SingleChildScrollView
        expect(find.byType(SingleChildScrollView), findsNothing);

        // Should still have Container and Text
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Scrollable false test'), findsOneWidget);
      });

      testWidgets('should handle scrollable with long content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test scrollable functionality with content that needs scrolling
        final scrollableText = 'Scrollable long content. ' * 50;

        await tester.pumpWidget(createTestWidget(
          SizedBox(
            height: 200, // Constrained height to force scrolling
            child: TextDisplayContainer(
              text: scrollableText,
              scrollable: true,
            ),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should be scrollable
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.text(scrollableText), findsOneWidget);

        // Should handle scrolling without layout errors
        final scrollView = tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
        expect(scrollView.child, isA<Container>());
      });
    });

    group('Expanded Parameter Testing', () {
      testWidgets('should wrap in Expanded when expanded=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 41-43 expanded wrapping
        const testText = 'Expanded true test';

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(
                text: testText,
                expanded: true,
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should wrap in Expanded
        expect(find.byType(Expanded), findsOneWidget);

        // Expanded should contain the content
        expect(
            find.descendant(
              of: find.byType(Expanded),
              matching: find.text('Expanded true test'),
            ),
            findsOneWidget);
      });

      testWidgets('should not wrap in Expanded when expanded=false (default)',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code condition - no wrapping when expanded=false
        const testText = 'Expanded false test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            text: testText,
            expanded: false,
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should not wrap in Expanded
        expect(find.byType(Expanded), findsNothing);

        // Should still have content
        expect(find.text('Expanded false test'), findsOneWidget);
      });

      testWidgets('should work in Flex layouts when expanded=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test expanded functionality in Column layout
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              Text('Header'),
              TextDisplayContainer(
                text: 'Expanded content',
                expanded: true,
              ),
              Text('Footer'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should work in Column layout
        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Expanded content'), findsOneWidget);
        expect(find.text('Footer'), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      });
    });

    group('Combined Parameter Testing', () {
      testWidgets('should handle both scrollable=true and expanded=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 37-43 combined wrapping
        const testText = 'Both true test';

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(
                text: testText,
                scrollable: true,
                expanded: true,
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should have both wrappers: Expanded(SingleChildScrollView(Container))
        expect(find.byType(Expanded), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Both true test'), findsOneWidget);

        // Verify hierarchy: Expanded contains SingleChildScrollView
        expect(
            find.descendant(
              of: find.byType(Expanded),
              matching: find.byType(SingleChildScrollView),
            ),
            findsOneWidget);
      });

      testWidgets('should handle scrollable=false and expanded=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test mixed parameters
        const testText = 'Mixed parameters test';

        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(
                text: testText,
                scrollable: false,
                expanded: true,
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should have Expanded but not SingleChildScrollView
        expect(find.byType(Expanded), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.text('Mixed parameters test'), findsOneWidget);

        // Verify hierarchy: Expanded contains Container directly
        expect(
            find.descendant(
              of: find.byType(Expanded),
              matching: find.byType(Container),
            ),
            findsOneWidget);
      });

      testWidgets('should handle scrollable=true and expanded=false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test other mixed parameters
        const testText = 'Other mixed test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            text: testText,
            scrollable: true,
            expanded: false,
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should have SingleChildScrollView but not Expanded
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Expanded), findsNothing);
        expect(find.text('Other mixed test'), findsOneWidget);
      });

      testWidgets('should handle both scrollable=false and expanded=false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test minimal wrapping
        const testText = 'Both false test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            text: testText,
            scrollable: false,
            expanded: false,
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should have neither wrapper - just Container directly
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(Expanded), findsNothing);
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Both false test'), findsOneWidget);
      });
    });

    group('Layout and Theme Integration', () {
      testWidgets('should work with different theme configurations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test theme dependency
        const testText = 'Theme integration test';

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(
              bodyMedium: TextStyle(
                  fontSize: 20.0,
                  color: Colors.red,
                  fontWeight: FontWeight.bold),
            ),
          ),
          home: Scaffold(
            body: const TextDisplayContainer(text: testText),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should adapt to different theme
        final textWidget =
            tester.widget<Text>(find.text('Theme integration test'));
        expect(textWidget.style!.fontSize, equals(20.0));
        expect(textWidget.style!.color, equals(Colors.red));
        expect(textWidget.style!.fontWeight, equals(FontWeight.bold));
      });

      testWidgets('should handle constrained layouts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test constrained container behavior
        const testText = 'Constrained layout test';

        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200,
            height: 150,
            child: const TextDisplayContainer(text: testText),
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should work within constraints
        expect(find.text('Constrained layout test'), findsOneWidget);
        expect(find.byType(SingleChildScrollView),
            findsOneWidget); // Default scrollable

        // Container should render properly within constraints
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should integrate with complex layouts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test integration in complex widget trees
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              Text('Header Text'),
              TextDisplayContainer(
                text: 'First container',
                expanded: false,
              ),
              SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextDisplayContainer(
                        text: 'Left expanded',
                        expanded: false, // Don't double-wrap in Expanded
                        scrollable: false,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextDisplayContainer(
                        text: 'Right expanded',
                        expanded: false, // Don't double-wrap in Expanded
                        scrollable: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle complex layout integration
        expect(find.text('Header Text'), findsOneWidget);
        expect(find.text('First container'), findsOneWidget);
        expect(find.text('Left expanded'), findsOneWidget);
        expect(find.text('Right expanded'), findsOneWidget);

        // Should have proper widget structure
        expect(find.byType(TextDisplayContainer), findsNWidgets(3));
        expect(
            find.byType(Expanded),
            findsNWidgets(
                3)); // Column's Expanded + Row's 2 Expanded widgets (TextDisplayContainers have expanded=false)
      });
    });

    group('AppColors and AppDimensions Integration', () {
      testWidgets('should use correct AppColors constants',
          (WidgetTester tester) async {
        // ULTRATHINK: Test AppColors integration
        const testText = 'AppColors test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Should use exact AppColors values
        expect(decoration.color, equals(AppColors.backgroundTint));
        expect(decoration.border, equals(Border.all(color: AppColors.divider)));
      });

      testWidgets('should use correct AppDimensions constants',
          (WidgetTester tester) async {
        // ULTRATHINK: Test AppDimensions integration
        const testText = 'AppDimensions test';

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(text: testText),
        ));

        expect(tester.takeException(), isNull);

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Should use exact AppDimensions values
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));
        expect(
            container.margin,
            equals(
                const EdgeInsets.symmetric(vertical: AppDimensions.spacingS)));
        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('should maintain consistent styling across instances',
          (WidgetTester tester) async {
        // ULTRATHINK: Test styling consistency
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(text: 'Container 1'),
              TextDisplayContainer(text: 'Container 2'),
              TextDisplayContainer(text: 'Container 3'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // All containers should have identical styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));

        for (final container in containers) {
          expect(container.padding,
              equals(const EdgeInsets.all(AppDimensions.paddingL)));
          expect(
              container.margin,
              equals(const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingS)));

          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, equals(AppColors.backgroundTint));
          expect(decoration.borderRadius,
              equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
          expect(
              decoration.border, equals(Border.all(color: AppColors.divider)));
        }
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose all parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => const TextDisplayContainer(text: 'test'), returnsNormally);
        expect(() => const TextDisplayContainer(text: 'test', expanded: true),
            returnsNormally);
        expect(
            () => const TextDisplayContainer(text: 'test', scrollable: false),
            returnsNormally);
        expect(
            () => const TextDisplayContainer(
                text: 'test', expanded: true, scrollable: false),
            returnsNormally);

        // Test parameter accessibility
        const widget = TextDisplayContainer(
            text: 'API test', expanded: true, scrollable: false);
        expect(widget, isA<Widget>());
        expect(widget.text, equals('API test'));
        expect(widget.expanded, equals(true));
        expect(widget.scrollable, equals(false));
      });

      testWidgets('should return proper Widget type',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify return type hierarchy
        const widget = TextDisplayContainer(text: 'Type test');
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<TextDisplayContainer>());
      });

      testWidgets('should maintain StatelessWidget behavior',
          (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        Widget createSameWidget() => const TextDisplayContainer(
            text: 'Consistency test', expanded: false, scrollable: false);

        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);

        // First build
        expect(find.text('Consistency test'), findsOneWidget);
        expect(find.byType(Expanded), findsNothing); // expanded=false
        expect(find.byType(SingleChildScrollView),
            findsNothing); // scrollable=false

        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);

        expect(find.text('Consistency test'), findsOneWidget);
        expect(find.byType(Expanded), findsNothing); // expanded=false
        expect(find.byType(SingleChildScrollView),
            findsNothing); // scrollable=false
      });

      testWidgets('should work with key parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('text-display-container-key');

        await tester.pumpWidget(createTestWidget(
          const TextDisplayContainer(
            key: testKey,
            text: 'Key test',
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Key test'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should provide consistent text display interface',
          (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - consistent text display container
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(
                  text: 'Instructions: Follow these steps carefully'),
              TextDisplayContainer(
                  text: 'Description: This is the main content area'),
              TextDisplayContainer(
                  text: 'Notes: Additional information goes here'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should provide consistent styling for different text types
        expect(find.byType(TextDisplayContainer), findsNWidgets(3));
        expect(find.text('Instructions: Follow these steps carefully'),
            findsOneWidget);
        expect(find.text('Description: This is the main content area'),
            findsOneWidget);
        expect(find.text('Notes: Additional information goes here'),
            findsOneWidget);

        // All should use consistent container styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));
        for (final container in containers) {
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, equals(AppColors.backgroundTint));
          expect(
              decoration.border, equals(Border.all(color: AppColors.divider)));
        }
      });

      testWidgets('should serve as flexible layout component',
          (WidgetTester tester) async {
        // ULTRATHINK: Test flexibility for different layout needs
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              TextDisplayContainer(
                text: 'Fixed height content',
                scrollable: false,
                expanded: false,
              ),
              SizedBox(height: 10),
              TextDisplayContainer(
                text:
                    'Scrollable content that might be very long and need scrolling',
                scrollable: true,
                expanded: false,
              ),
              SizedBox(height: 10),
              TextDisplayContainer(
                text: 'Expanded content that takes remaining space',
                expanded: true,
                scrollable: true,
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should serve different layout purposes
        expect(find.byType(TextDisplayContainer), findsNWidgets(3));

        // First: no wrapping
        // Second: SingleChildScrollView only
        // Third: Expanded + SingleChildScrollView (TextDisplayContainer creates its own Expanded)
        expect(find.byType(SingleChildScrollView), findsNWidgets(2));
        expect(find.byType(Expanded),
            findsOneWidget); // Only TextDisplayContainer's internal Expanded
      });

      testWidgets('should handle real-world content display scenarios',
          (WidgetTester tester) async {
        // ULTRATHINK: Test realistic usage patterns
        final longContent = '''
This is a realistic example of content that might be displayed in the app:

Recipe Instructions:
1. Preheat oven to 350°F
2. Mix dry ingredients in a large bowl
3. Combine wet ingredients separately
4. Fold wet ingredients into dry mixture
5. Pour into prepared baking pan
6. Bake for 25-30 minutes until golden brown

Notes: This recipe serves 8-10 people. Store in airtight container for up to 3 days.

Ingredients sourced from local Swedish suppliers with åäö characters.
        ''';

        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              const TextDisplayContainer(
                text: 'Recipe Title: Swedish Cardamom Cake',
                scrollable: false,
              ),
              const SizedBox(height: 10),
              TextDisplayContainer(
                text: longContent,
                expanded: true,
                scrollable: true,
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);

        // Should handle realistic content scenarios
        expect(
            find.text('Recipe Title: Swedish Cardamom Cake'), findsOneWidget);
        expect(find.textContaining('Recipe Instructions:'), findsOneWidget);
        expect(
            find.textContaining('Swedish suppliers with åäö'), findsOneWidget);

        // Should maintain proper layout structure
        expect(find.byType(Expanded),
            findsOneWidget); // Only TextDisplayContainer's internal Expanded
        expect(find.byType(SingleChildScrollView),
            findsOneWidget); // Only the expanded one is scrollable
      });
    });
  });
}
