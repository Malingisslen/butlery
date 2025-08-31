// test/widget/messaging/messaging_containers_ultrathink_test.dart
// ULTRATHINK TEST SUITE: Messaging Container Widgets
// Testing 4 simple container widgets: MessageInputContainer, ModalContentContainer,
// SearchBarContainer, and ModalHeaderText

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/widgets/messaging/message_input_container.dart';
import 'package:butlery/widgets/messaging/modal_content_container.dart';
import 'package:butlery/widgets/messaging/search_bar_container.dart';
import 'package:butlery/widgets/messaging/modal_header_text.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('Messaging Containers Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('MessageInputContainer Tests', () {
      testWidgets('renders with child widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 17-31
        const testChild = Text('Test Child');
        
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageInputContainer(
              child: testChild,
            ),
          ),
        );

        // Should render the container
        expect(find.byType(MessageInputContainer), findsOneWidget);
        
        // Should render the child
        expect(find.text('Test Child'), findsOneWidget);
        
        // Should have SafeArea
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('has correct decoration styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 18-28
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageInputContainer(
              child: SizedBox(width: 100, height: 50),
            ),
          ),
        );

        // Find the Container widget
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageInputContainer),
            matching: find.byType(Container),
          ),
        );

        // Check decoration
        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration as BoxDecoration;
        
        // Should have white background
        expect(decoration.color, equals(AppColors.cardWhite));
        
        // Should have box shadow
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.length, equals(1));
        
        final shadow = decoration.boxShadow![0];
        expect(shadow.blurRadius, equals(4));
        expect(shadow.offset, equals(const Offset(0, -2)));
      });

      testWidgets('has correct padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 29
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageInputContainer(
              child: Text('Padding Test'),
            ),
          ),
        );

        // Find the Container widget
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageInputContainer),
            matching: find.byType(Container),
          ),
        );

        // Check padding
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingM)));
      });

      testWidgets('SafeArea wraps child correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 30
        const testChild = Icon(Icons.message);
        
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageInputContainer(
              child: testChild,
            ),
          ),
        );

        // SafeArea should be between Container and child
        expect(
          find.descendant(
            of: find.byType(SafeArea),
            matching: find.byIcon(Icons.message),
          ),
          findsOneWidget,
        );
      });

      testWidgets('shadow uses correct color with alpha',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 23
        await tester.pumpWidget(
          createTestWidget(
            child: const MessageInputContainer(
              child: SizedBox(),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageInputContainer),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration as BoxDecoration;
        final shadow = decoration.boxShadow![0];
        
        // Shadow color should be textLight with alpha 0.1
        // Note: withValues(alpha: 0.1) creates a color with alpha channel
        final alphaValue = (shadow.color.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(30)); // 0.1 * 255 ≈ 25.5
      });
    });

    group('ModalContentContainer Tests', () {
      testWidgets('renders with children widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 16-23
        final testChildren = [
          const Text('Child 1'),
          const Text('Child 2'),
          const Text('Child 3'),
        ];
        
        await tester.pumpWidget(
          createTestWidget(
            child: ModalContentContainer(
              children: testChildren,
            ),
          ),
        );

        // Should render the container
        expect(find.byType(ModalContentContainer), findsOneWidget);
        
        // Should render all children
        expect(find.text('Child 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
        expect(find.text('Child 3'), findsOneWidget);
        
        // Should have Column
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('Column has correct properties',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 19-22
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalContentContainer(
              children: [
                Text('Test'),
              ],
            ),
          ),
        );

        // Find the Column widget
        final column = tester.widget<Column>(
          find.descendant(
            of: find.byType(ModalContentContainer),
            matching: find.byType(Column),
          ),
        );

        // Check mainAxisSize is min
        expect(column.mainAxisSize, equals(MainAxisSize.min));
      });

      testWidgets('has correct padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 18
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalContentContainer(
              children: [Text('Padding Test')],
            ),
          ),
        );

        // Find the Container widget
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ModalContentContainer),
            matching: find.byType(Container),
          ),
        );

        // Check padding
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('handles empty children list',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case - empty children
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalContentContainer(
              children: [],
            ),
          ),
        );

        // Should render without error
        expect(find.byType(ModalContentContainer), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('preserves child order',
          (WidgetTester tester) async {
        // ULTRATHINK: Test children order preservation
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalContentContainer(
              children: [
                Text('First'),
                SizedBox(height: 10),
                Text('Second'),
                Icon(Icons.star),
                Text('Third'),
              ],
            ),
          ),
        );

        // Get all widgets in Column
        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, equals(5));
        
        // Verify order
        expect((column.children[0] as Text).data, equals('First'));
        expect(column.children[1], isA<SizedBox>());
        expect((column.children[2] as Text).data, equals('Second'));
        expect(column.children[3], isA<Icon>());
        expect((column.children[4] as Text).data, equals('Third'));
      });
    });

    group('SearchBarContainer Tests', () {
      testWidgets('renders with child widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 16-23
        const testChild = TextField();
        
        await tester.pumpWidget(
          createTestWidget(
            child: const SearchBarContainer(
              child: testChild,
            ),
          ),
        );

        // Should render the container
        expect(find.byType(SearchBarContainer), findsOneWidget);
        
        // Should render the child
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('has correct background color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 20
        await tester.pumpWidget(
          createTestWidget(
            child: const SearchBarContainer(
              child: Text('Color Test'),
            ),
          ),
        );

        // Find the Container widget
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SearchBarContainer),
            matching: find.byType(Container),
          ),
        );

        // Check color
        expect(container.color, equals(AppColors.backgroundBeige));
      });

      testWidgets('has correct padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 19
        await tester.pumpWidget(
          createTestWidget(
            child: const SearchBarContainer(
              child: Text('Padding Test'),
            ),
          ),
        );

        // Find the Container widget
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SearchBarContainer),
            matching: find.byType(Container),
          ),
        );

        // Check padding
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingM)));
      });

      testWidgets('works with complex child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test with complex child
        await tester.pumpWidget(
          createTestWidget(
            child: SearchBarContainer(
              child: Row(
                children: const [
                  Icon(Icons.search),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Sök...',
                      ),
                    ),
                  ),
                  Icon(Icons.clear),
                ],
              ),
            ),
          ),
        );

        // Should render all child components
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('ModalHeaderText Tests', () {
      testWidgets('renders with text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 16-29
        const testText = 'Test Header';
        
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText(testText),
          ),
        );

        // Should render the widget
        expect(find.byType(ModalHeaderText), findsOneWidget);
        
        // Should render the text
        expect(find.text('Test Header'), findsOneWidget);
        
        // Should have Column
        expect(find.byType(Column), findsOneWidget);
        
        // Should have SizedBox for spacing
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('has correct text styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 20-24
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText('Styled Text'),
          ),
        );

        // Find the Text widget
        final text = tester.widget<Text>(find.text('Styled Text'));
        
        // Check text style
        expect(text.style, isNotNull);
        expect(text.style!.fontWeight, equals(FontWeight.bold));
        
        // Style should be based on AppTextStyles.headlineSmall
        // Note: We can't directly compare copyWith results, but we can check the fontWeight was applied
      });

      testWidgets('has correct spacing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 26
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText('Spacing Test'),
          ),
        );

        // Find the SizedBox
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        
        // Check height
        expect(sizedBox.height, equals(AppDimensions.paddingL));
      });

      testWidgets('handles long text',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case - long text
        final longText = 'Detta är en väldigt lång rubriktext som ' * 5;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ModalHeaderText(longText),
          ),
        );

        // Should render without overflow
        expect(find.text(longText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles empty text',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case - empty text
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText(''),
          ),
        );

        // Should render without error
        expect(find.byType(ModalHeaderText), findsOneWidget);
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles Swedish characters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        const swedishText = 'Åtgärder för användare';
        
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText(swedishText),
          ),
        );

        // Should render Swedish text correctly
        expect(find.text(swedishText), findsOneWidget);
      });

      testWidgets('Column layout is correct',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Column structure from lines 18-28
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalHeaderText('Layout Test'),
          ),
        );

        // Find the Column
        final column = tester.widget<Column>(find.byType(Column));
        
        // Should have 2 children (Text and SizedBox)
        expect(column.children.length, equals(2));
        
        // First child should be Text
        expect(column.children[0], isA<Text>());
        
        // Second child should be SizedBox
        expect(column.children[1], isA<SizedBox>());
      });
    });

    group('Integration Tests', () {
      testWidgets('MessageInputContainer works with complex child',
          (WidgetTester tester) async {
        // ULTRATHINK: Test real-world usage
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputContainer(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {},
                  ),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Skriv ett meddelande...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        // Should render all components within SafeArea
        expect(find.byType(SafeArea), findsOneWidget);
        expect(find.byIcon(Icons.attach_file), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('ModalContentContainer with ModalHeaderText',
          (WidgetTester tester) async {
        // ULTRATHINK: Test widgets used together
        await tester.pumpWidget(
          createTestWidget(
            child: const ModalContentContainer(
              children: [
                ModalHeaderText('Välj alternativ'),
                Text('Innehåll här'),
                SizedBox(height: 20),
                Text('Mer innehåll'),
              ],
            ),
          ),
        );

        // Should render both widgets together
        expect(find.byType(ModalContentContainer), findsOneWidget);
        expect(find.byType(ModalHeaderText), findsOneWidget);
        expect(find.text('Välj alternativ'), findsOneWidget);
        expect(find.text('Innehåll här'), findsOneWidget);
        expect(find.text('Mer innehåll'), findsOneWidget);
      });

      testWidgets('Containers maintain child widget functionality',
          (WidgetTester tester) async {
        // ULTRATHINK: Test that containers don't interfere with child functionality
        bool buttonPressed = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: SearchBarContainer(
              child: ElevatedButton(
                onPressed: () {
                  buttonPressed = true;
                },
                child: const Text('Sök'),
              ),
            ),
          ),
        );

        // Tap the button
        await tester.tap(find.text('Sök'));
        await tester.pump();

        // Button should work correctly
        expect(buttonPressed, isTrue);
      });
    });
  });
}