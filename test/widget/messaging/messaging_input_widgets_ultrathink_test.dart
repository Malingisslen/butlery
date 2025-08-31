// test/widget/messaging/messaging_input_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: Messaging Input Widgets
// Testing 3 widgets: TypingIndicatorContainer, MessageInputField, StyledModalBottomSheet

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/widgets/messaging/typing_indicator_container.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/widgets/messaging/styled_modal_bottom_sheet.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('Messaging Input Widgets Ultrathink Tests', () {
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

    group('TypingIndicatorContainer Tests', () {
      testWidgets('shows nothing when typingUsers is empty',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 19-21
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: [],
            ),
          ),
        );

        // Should render SizedBox.shrink (nothing visible)
        expect(find.byType(TypingIndicatorContainer), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('skriver'), findsNothing);
      });

      testWidgets('shows single user typing with Swedish text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 23-49
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['Anna'],
            ),
          ),
        );

        // Should show typing indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Should show Swedish text
        expect(find.text('Anna skriver...'), findsOneWidget);
      });

      testWidgets('shows multiple users typing with Swedish text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 41 - join functionality
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['Anna', 'Erik', 'Maria'],
            ),
          ),
        );

        // Should show all users joined with commas
        expect(find.text('Anna, Erik, Maria skriver...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('has correct container styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 23-28
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['Test User'],
            ),
          ),
        );

        // Find the Container
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(TypingIndicatorContainer),
            matching: find.byType(Container),
          ).first,
        );

        // Check padding
        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        )));
        
        // Check color
        expect(container.color, equals(AppColors.backgroundBeige));
      });

      testWidgets('CircularProgressIndicator has correct properties',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 31-38
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['User'],
            ),
          ),
        );

        // Find the CircularProgressIndicator
        final progressIndicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        // Check properties
        expect(progressIndicator.strokeWidth, equals(2));
        expect(progressIndicator.valueColor, isA<AlwaysStoppedAnimation<Color>>());
        
        final valueColor = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
        expect(valueColor.value, equals(AppColors.textMedium));
      });

      testWidgets('indicator has correct size constraints',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 31-33
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['User'],
            ),
          ),
        );

        // Find the SizedBox containing the indicator
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(Row),
            matching: find.byType(SizedBox),
          ).first,
        );

        expect(sizedBox.width, equals(20));
        expect(sizedBox.height, equals(20));
      });

      testWidgets('handles special characters in user names',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case - special characters
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['Åsa Östman', 'Erik-Johan'],
            ),
          ),
        );

        expect(find.text('Åsa Östman, Erik-Johan skriver...'), findsOneWidget);
      });

      testWidgets('text has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 42-45
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicatorContainer(
              typingUsers: ['Anna'],
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Anna skriver...'));
        expect(text.style?.color, equals(AppColors.textMedium));
        expect(text.style?.fontStyle, equals(FontStyle.italic));
      });
    });

    group('MessageInputField Tests', () {
      late TextEditingController controller;
      late FocusNode focusNode;

      setUp(() {
        controller = TextEditingController();
        focusNode = FocusNode();
      });

      tearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      testWidgets('renders with all required properties',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 24-53
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Skriv ett meddelande...',
            ),
          ),
        );

        // Should render the field
        expect(find.byType(MessageInputField), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(DecoratedBox), findsOneWidget);
      });

      testWidgets('shows hint text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 40-44
        const hintText = 'Skriv här...';
        
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: hintText,
            ),
          ),
        );

        // Should show hint text
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, equals(hintText));
      });

      testWidgets('has correct decoration styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 25-33
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        // Find the DecoratedBox
        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );

        // Check decoration
        expect(decoratedBox.decoration, isA<BoxDecoration>());
        final decoration = decoratedBox.decoration as BoxDecoration;
        
        expect(decoration.color, equals(AppColors.backgroundBeige));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusL)));
        expect(decoration.border, isNotNull);
      });

      testWidgets('supports multi-line input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 37-38
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, equals(5));
        expect(textField.minLines, equals(1));
      });

      testWidgets('has sentence capitalization',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 39
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.textCapitalization, equals(TextCapitalization.sentences));
      });

      testWidgets('handles text input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test controller functionality
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        // Enter text
        await tester.enterText(find.byType(TextField), 'Hej från Sverige!');
        await tester.pump();

        // Controller should have the text
        expect(controller.text, equals('Hej från Sverige!'));
      });

      testWidgets('handles onSubmitted callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 51
        bool submitted = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
              onSubmitted: () {
                submitted = true;
              },
            ),
          ),
        );

        // Submit text
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Callback should be called
        expect(submitted, isTrue);
      });

      testWidgets('works without onSubmitted callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null callback handling from line 51
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
              onSubmitted: null,
            ),
          ),
        );

        // Should render without error
        expect(find.byType(MessageInputField), findsOneWidget);
        
        // Submit should not crash
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        
        expect(tester.takeException(), isNull);
      });

      testWidgets('has correct content padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 46-49
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.contentPadding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        )));
      });

      testWidgets('focus node works correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test focus node functionality
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        // Initially not focused
        expect(focusNode.hasFocus, isFalse);

        // Tap to focus
        await tester.tap(find.byType(TextField));
        await tester.pump();

        // Should be focused
        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('handles long text correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test multi-line expansion
        final longText = 'Detta är en lång text som bör expandera fältet. ' * 10;
        
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Test',
            ),
          ),
        );

        // Enter long text
        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        // Should handle without overflow
        expect(controller.text, equals(longText));
        expect(tester.takeException(), isNull);
      });
    });

    group('StyledModalBottomSheet Tests', () {
      testWidgets('shows modal with correct shape',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 9-22
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      StyledModalBottomSheet.show(
                        context: context,
                        child: const SizedBox(
                          height: 200,
                          child: Center(
                            child: Text('Modal Content'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap button to open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Modal should be shown
        expect(find.text('Modal Content'), findsOneWidget);
        
        // Should have rounded top corners
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          ),
        );
        
        expect(material.shape, isA<RoundedRectangleBorder>());
        final shape = material.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, equals(const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        )));
      });

      testWidgets('returns value when closed',
          (WidgetTester tester) async {
        // ULTRATHINK: Test generic return type from line 9
        String? result;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await StyledModalBottomSheet.show<String>(
                        context: context,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, 'test_value');
                            },
                            child: const Text('Close'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Close modal with value
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Should return the value
        expect(result, equals('test_value'));
      });

      testWidgets('handles null return when dismissed',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dismissal behavior
        String? result;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await StyledModalBottomSheet.show<String>(
                        context: context,
                        child: const SizedBox(
                          height: 200,
                          child: Center(child: Text('Content')),
                        ),
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Dismiss by tapping outside
        await tester.tapAt(const Offset(200, 100));
        await tester.pumpAndSettle();

        // Should return null
        expect(result, isNull);
      });

      testWidgets('works with complex child widgets',
          (WidgetTester tester) async {
        // ULTRATHINK: Test child flexibility
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      StyledModalBottomSheet.show(
                        context: context,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            ListTile(
                              leading: Icon(Icons.photo),
                              title: Text('Välj bild'),
                            ),
                            ListTile(
                              leading: Icon(Icons.camera),
                              title: Text('Ta foto'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Complex child should render
        expect(find.text('Välj bild'), findsOneWidget);
        expect(find.text('Ta foto'), findsOneWidget);
        expect(find.byIcon(Icons.photo), findsOneWidget);
        expect(find.byIcon(Icons.camera), findsOneWidget);
      });

      testWidgets('modal sheet is scrollable for large content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test scrollability
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      StyledModalBottomSheet.show(
                        context: context,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: 20,
                          itemBuilder: (context, index) => ListTile(
                            title: Text('Item $index'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Should show some items
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
        
        // Should be scrollable
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('Integration Tests', () {
      testWidgets('TypingIndicatorContainer with real user names',
          (WidgetTester tester) async {
        // ULTRATHINK: Test real-world Swedish names
        final typingUsers = ['Anna Andersson', 'Erik Svensson', 'Maria Nilsson'];
        
        await tester.pumpWidget(
          createTestWidget(
            child: TypingIndicatorContainer(typingUsers: typingUsers),
          ),
        );

        expect(find.text('Anna Andersson, Erik Svensson, Maria Nilsson skriver...'), 
               findsOneWidget);
      });

      testWidgets('MessageInputField with Swedish keyboard input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish text input
        final controller = TextEditingController();
        final focusNode = FocusNode();
        
        await tester.pumpWidget(
          createTestWidget(
            child: MessageInputField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Skriv ett meddelande...',
            ),
          ),
        );

        // Enter Swedish text with special characters
        await tester.enterText(
          find.byType(TextField), 
          'Hej! Hur mår du? Jag äter köttbullar och lingon.'
        );
        await tester.pump();

        expect(controller.text, 
               equals('Hej! Hur mår du? Jag äter köttbullar och lingon.'));
      });

      testWidgets('StyledModalBottomSheet with MessageInputField',
          (WidgetTester tester) async {
        // ULTRATHINK: Test widgets used together
        final controller = TextEditingController();
        final focusNode = FocusNode();
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      StyledModalBottomSheet.show(
                        context: context,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: MessageInputField(
                            controller: controller,
                            focusNode: focusNode,
                            hintText: 'Skriv en kommentar...',
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Input Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text('Open Input Modal'));
        await tester.pumpAndSettle();

        // Input field should be in modal
        expect(find.byType(MessageInputField), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        
        // Should be able to type in the field
        await tester.enterText(find.byType(TextField), 'Test från modal');
        await tester.pump();
        
        expect(controller.text, equals('Test från modal'));
        
        controller.dispose();
        focusNode.dispose();
      });
    });
  });
}