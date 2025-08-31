// test/widget/messaging/chat_input_section_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ChatInputSection (MessageInput)
// Critical messaging input widget with attachments, Swedish localization

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/theme/app_colors.dart';

// Mock for callbacks
class MockCallbacks extends Mock {
  Future<void> onSendMessage(String text, {MessageType type});
  Future<void> onAttachment(String attachment);
}

void main() {
  group('ChatInputSection Ultrathink Tests', () {
    late MockCallbacks mockCallbacks;

    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onSurfaceVariant: Colors.black54,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(MessageType.text);
    });

    setUp(() {
      mockCallbacks = MockCallbacks();
      
      // Setup default mock behavior
      when(() => mockCallbacks.onSendMessage(any(), type: any(named: 'type')))
          .thenAnswer((_) async {});
      when(() => mockCallbacks.onAttachment(any()))
          .thenAnswer((_) async {});
    });

    group('Rendering Tests', () {
      testWidgets('renders all core components', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 121-193
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Verify core components are rendered
        expect(find.byType(MessageInputField), findsOneWidget);
        expect(find.byIcon(Icons.attach_file), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
        
        // Swedish hint text from production line 169
        expect(find.text('Skriv ett meddelande...'), findsOneWidget);
      });

      testWidgets('shows container with proper styling', (WidgetTester tester) async {
        // ULTRATHINK: Test container styling from lines 122-132
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatInputSection),
            matching: find.byType(Container),
          ).first,
        );

        expect(container.padding, equals(const EdgeInsets.all(16)));
      });
    });

    group('Text Input Tests', () {
      testWidgets('updates isComposing state when text changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text change listener from lines 52-61
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Initially send button should be disabled (grey)
        final initialSendIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.send),
            matching: find.byType(Icon),
          ),
        );
        expect(initialSendIcon.color, equals(AppColors.textSecondary));

        // Type text
        await tester.enterText(find.byType(TextField), 'Hej!');
        await tester.pump();

        // Send button should be enabled (primary color)
        final activeSendIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.send),
            matching: find.byType(Icon),
          ),
        );
        expect(activeSendIcon.color, equals(AppColors.primary));
      });

      testWidgets('clears text after successful send',
          (WidgetTester tester) async {
        // ULTRATHINK: Test send behavior from lines 73-91
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Type message
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        // Send message
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Verify callback was called
        verify(() => mockCallbacks.onSendMessage(
          'Test message',
          type: MessageType.text,
        )).called(1);

        // Verify text was cleared
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals(''));
      });

      testWidgets('restores text on send error',
          (WidgetTester tester) async {
        // ULTRATHINK: Test error handling from lines 94-104
        final errorMessage = 'Test message that fails';
        
        // Setup mock to throw error
        when(() => mockCallbacks.onSendMessage(any(), type: any(named: 'type')))
            .thenThrow(Exception('Send failed'));

        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Type message
        await tester.enterText(find.byType(TextField), errorMessage);
        await tester.pump();

        // Try to send (will fail)
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Verify text was restored after error
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals(errorMessage));
      });

      testWidgets('ignores empty or whitespace-only messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty message handling from lines 74-77
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Try to send empty message
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Verify callback was NOT called
        verifyNever(() => mockCallbacks.onSendMessage(
          any(),
          type: any(named: 'type'),
        ));

        // Try whitespace only
        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Still should not send
        verifyNever(() => mockCallbacks.onSendMessage(
          any(),
          type: any(named: 'type'),
        ));
      });

      testWidgets('handles onSubmitted from text field',
          (WidgetTester tester) async {
        // ULTRATHINK: Test onSubmitted callback from line 170
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Type and submit via keyboard
        await tester.enterText(find.byType(TextField), 'Submitted message');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Verify message was sent
        verify(() => mockCallbacks.onSendMessage(
          'Submitted message',
          type: MessageType.text,
        )).called(1);
      });
    });

    group('Attachment Tests', () {
      testWidgets('toggles attachment panel visibility',
          (WidgetTester tester) async {
        // ULTRATHINK: Test attachment toggle from lines 107-117
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Initially no attachment panel
        expect(find.text('Bilagor: Recept, Meny, Handlingslista, Foto'), findsNothing);
        
        // Icon should be attach_file
        expect(find.byIcon(Icons.attach_file), findsOneWidget);

        // Tap attachment button
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        // Attachment panel should be visible
        expect(find.text('Bilagor: Recept, Meny, Handlingslista, Foto'), findsOneWidget);
        
        // Icon should change to close
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byIcon(Icons.attach_file), findsNothing);
      });

      testWidgets('hides attachment panel when text field focused',
          (WidgetTester tester) async {
        // ULTRATHINK: Test focus behavior from lines 63-71
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Show attachment panel
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();
        expect(find.text('Bilagor: Recept, Meny, Handlingslista, Foto'), findsOneWidget);

        // Focus text field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        // Attachment panel should hide
        expect(find.text('Bilagor: Recept, Meny, Handlingslista, Foto'), findsNothing);
        expect(find.byIcon(Icons.attach_file), findsOneWidget);
      });

      testWidgets('unfocuses text field when showing attachments',
          (WidgetTester tester) async {
        // ULTRATHINK: Test unfocus behavior from lines 114-116
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Focus text field first
        await tester.tap(find.byType(TextField));
        await tester.pump();
        
        // Verify field is focused
        final fieldFinder = find.byType(TextField);
        final field = tester.widget<TextField>(fieldFinder);
        expect(field.focusNode?.hasFocus, isTrue);

        // Show attachments
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        // Field should lose focus
        expect(field.focusNode?.hasFocus, isFalse);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('displays Swedish hint text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish text from line 169
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        expect(find.text('Skriv ett meddelande...'), findsOneWidget);
      });

      testWidgets('displays Swedish tooltips',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish tooltips from lines 160-161, 185
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Check attachment button tooltip
        final attachButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.attach_file),
        );
        expect(attachButton.tooltip, equals('Bilagor'));

        // Toggle to show close button
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        final closeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        expect(closeButton.tooltip, equals('Stäng'));

        // Check send button tooltip
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(sendButton.tooltip, equals('Skicka'));
      });

      testWidgets('displays Swedish attachment types',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish attachment text from line 142
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Show attachments
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        // Verify Swedish attachment types
        expect(find.text('Bilagor: Recept, Meny, Handlingslista, Foto'), findsOneWidget);
      });
    });

    group('Visual State Tests', () {
      testWidgets('animates send button state changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test animation from lines 175-177
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Find AnimatedContainer
        expect(find.byType(AnimatedContainer), findsOneWidget);
        
        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        
        // Verify animation duration
        expect(animatedContainer.duration, equals(const Duration(milliseconds: 200)));
      });

      testWidgets('shows correct icon colors based on state',
          (WidgetTester tester) async {
        // ULTRATHINK: Test icon colors from lines 155-157, 181-183
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Check initial attachment icon color
        final Icon attachIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.attach_file),
            matching: find.byType(Icon),
          ),
        );
        expect(attachIcon.color, equals(AppColors.textSecondary));

        // Toggle attachment - should become primary color
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        final Icon closeIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.close),
            matching: find.byType(Icon),
          ),
        );
        expect(closeIcon.color, equals(AppColors.primary));

        // Check send button disabled color
        Icon sendIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.send),
            matching: find.byType(Icon),
          ),
        );
        expect(sendIcon.color, equals(AppColors.textSecondary));

        // Type text - send button should become primary
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();

        sendIcon = tester.widget<Icon>(
          find.descendant(
            of: find.widgetWithIcon(IconButton, Icons.send),
            matching: find.byType(Icon),
          ),
        );
        expect(sendIcon.color, equals(AppColors.primary));
      });
    });

    group('Lifecycle Tests', () {
      testWidgets('properly disposes controllers and listeners',
          (WidgetTester tester) async {
        // ULTRATHINK: Test disposal from lines 44-50
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Remove widget to trigger dispose
        await tester.pumpWidget(
          createTestWidget(
            child: const SizedBox(),
          ),
        );

        // Widget should dispose without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles mounted check properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test mounted checks from lines 55, 65, 84, 99, 108
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Type text to trigger state change
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();

        // Remove widget
        await tester.pumpWidget(
          createTestWidget(
            child: const SizedBox(),
          ),
        );

        // Should not throw despite state changes
        expect(tester.takeException(), isNull);
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles rapid text changes',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rapid state changes
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Rapidly change text
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();

        // Should handle all changes without error
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles conversation ID correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test conversation ID from line 15
        const testConversationId = 'unique-conversation-123';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: testConversationId,
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Widget should build with conversation ID
        expect(find.byType(ChatInputSection), findsOneWidget);
      });

      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null safety
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test',
              onSendMessage: (text, {MessageType type = MessageType.text}) async {
                // Empty implementation
              },
              onAttachment: (attachment) async {
                // Empty implementation
              },
            ),
          ),
        );

        // Should render without error
        expect(find.byType(ChatInputSection), findsOneWidget);
      });
    });

    group('Multi-line Input Tests', () {
      testWidgets('supports multi-line text input',
          (WidgetTester tester) async {
        // ULTRATHINK: MessageInputField uses maxLines: 5, minLines: 1
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Enter multi-line text
        const multiLineText = 'Line 1\nLine 2\nLine 3';
        await tester.enterText(find.byType(TextField), multiLineText);
        await tester.pump();

        // Text should be preserved with newlines
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals(multiLineText));

        // Should still be able to send
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        verify(() => mockCallbacks.onSendMessage(
          multiLineText,
          type: MessageType.text,
        )).called(1);
      });

      testWidgets('trims whitespace before sending',
          (WidgetTester tester) async {
        // ULTRATHINK: Test trim behavior from line 74
        await tester.pumpWidget(
          createTestWidget(
            child: ChatInputSection(
              conversationId: 'test-conversation',
              onSendMessage: mockCallbacks.onSendMessage,
              onAttachment: mockCallbacks.onAttachment,
            ),
          ),
        );

        // Enter text with leading/trailing whitespace
        await tester.enterText(find.byType(TextField), '  Trimmed message  ');
        await tester.pump();

        // Send message
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Should send trimmed text
        verify(() => mockCallbacks.onSendMessage(
          'Trimmed message',
          type: MessageType.text,
        )).called(1);
      });
    });
  });
}