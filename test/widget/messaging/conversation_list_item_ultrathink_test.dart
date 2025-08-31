// test/widget/messaging/conversation_list_item_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ConversationListItem
// 252-line critical messaging widget with avatars, unread indicators, Swedish timestamps

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/widgets/messaging/conversation_list_item.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Create mock for conversation and message
class MockConversation extends Mock implements Conversation {}
class MockMessage extends Mock implements Message {}

void main() {
  group('ConversationListItem Ultrathink Tests', () {
    late MockConversation mockConversation;
    late MockMessage mockMessage;
    const currentUserId = 'test-user-id';
    
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
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    setUp(() {
      mockConversation = MockConversation();
      mockMessage = MockMessage();
      
      // Setup default mock behavior
      when(() => mockConversation.getDisplayTitle(any())).thenReturn('Test Conversation');
      when(() => mockConversation.getDisplayAvatarUrl(any())).thenReturn(null);
      when(() => mockConversation.hasUnreadMessages(any())).thenReturn(false);
      when(() => mockConversation.formattedLastActivity).thenReturn('12:34');
      when(() => mockConversation.isGroup).thenReturn(false);
      when(() => mockConversation.lastMessage).thenReturn(mockMessage);
      
      // Setup message mock
      when(() => mockMessage.isSystemMessage).thenReturn(false);
      when(() => mockMessage.isFromCurrentUser(any())).thenReturn(false);
      when(() => mockMessage.displayContent).thenReturn('Hej! Hur mår du?');
      when(() => mockMessage.content).thenReturn('Hej! Hur mår du?');
      when(() => mockMessage.senderDisplayName).thenReturn('Anna');
    });

    group('Rendering Tests', () {
      testWidgets('renders all core components for direct conversation', 
          (WidgetTester tester) async {
        // ULTRATHINK: Test basic rendering from lines 39-129
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
              onTap: () {},
            ),
          ),
        );

        // Avatar should be rendered
        expect(find.byType(Stack), findsWidgets); // Multiple stacks for avatar
        
        // Title should be displayed
        expect(find.text('Test Conversation'), findsOneWidget);
        
        // Last message preview
        expect(find.text('Hej! Hur mår du?'), findsOneWidget);
        
        // Timestamp
        expect(find.text('12:34'), findsOneWidget);
      });

      testWidgets('renders group conversation with group icon', 
          (WidgetTester tester) async {
        // ULTRATHINK: Test group avatar from lines 141-143, 168-179
        when(() => mockConversation.isGroup).thenReturn(true);
        when(() => mockConversation.getDisplayTitle(any())).thenReturn('Familjegruppen');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Group icon should be displayed
        expect(find.byIcon(Icons.group), findsOneWidget);
        
        // Group title
        expect(find.text('Familjegruppen'), findsOneWidget);
      });

      testWidgets('shows online status indicator for direct conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test online status from lines 146-163
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
              showOnlineStatus: true,
            ),
          ),
        );

        // Find the online status indicator
        final onlineIndicator = find.descendant(
          of: find.byType(Stack),
          matching: find.byWidgetPredicate(
            (widget) => widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == AppColors.success &&
                (widget.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        
        expect(onlineIndicator, findsOneWidget);
      });
    });

    group('Unread Message Tests', () {
      testWidgets('shows unread indicator when messages are unread',
          (WidgetTester tester) async {
        // ULTRATHINK: Test unread indicator from lines 36, 116-119, 211-219
        when(() => mockConversation.hasUnreadMessages(any())).thenReturn(true);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Find the unread indicator (blue dot)
        final unreadIndicator = find.byWidgetPredicate(
          (widget) => widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == AppColors.primaryBlue &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
              widget.constraints?.maxWidth == AppDimensions.spacingSm,
        );
        
        expect(unreadIndicator, findsOneWidget);
      });

      testWidgets('applies bold text styling for unread conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text styling from lines 66-73, 103-110
        when(() => mockConversation.hasUnreadMessages(any())).thenReturn(true);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Title should be bold
        final titleText = tester.widget<Text>(find.text('Test Conversation'));
        expect(titleText.style?.fontWeight, equals(FontWeight.bold));
        
        // Last message should be semi-bold
        final messageText = tester.widget<Text>(find.text('Hej! Hur mår du?'));
        expect(messageText.style?.fontWeight, equals(FontWeight.w500));
        
        // Timestamp should be primary color
        final timestampText = tester.widget<Text>(find.text('12:34'));
        expect(timestampText.style?.color, equals(AppColors.primaryBlue));
      });

      testWidgets('shows normal styling for read conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test normal styling for read messages
        when(() => mockConversation.hasUnreadMessages(any())).thenReturn(false);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Title should not be bold
        final titleText = tester.widget<Text>(find.text('Test Conversation'));
        expect(titleText.style?.fontWeight, isNot(equals(FontWeight.bold)));
        
        // Timestamp should be medium color
        final timestampText = tester.widget<Text>(find.text('12:34'));
        expect(timestampText.style?.color, equals(AppColors.textMedium));
      });
    });

    group('Message Preview Tests', () {
      testWidgets('shows correct preview for direct conversation from other user',
          (WidgetTester tester) async {
        // ULTRATHINK: Test message preview from lines 236-242
        when(() => mockConversation.isGroup).thenReturn(false);
        when(() => mockMessage.isFromCurrentUser(currentUserId)).thenReturn(false);
        when(() => mockMessage.displayContent).thenReturn('Vad gör du?');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show message without prefix
        expect(find.text('Vad gör du?'), findsOneWidget);
        expect(find.text('Du: Vad gör du?'), findsNothing);
      });

      testWidgets('shows "Du:" prefix for messages from current user',
          (WidgetTester tester) async {
        // ULTRATHINK: Test current user message from lines 238-239, 246-247
        when(() => mockMessage.isFromCurrentUser(currentUserId)).thenReturn(true);
        when(() => mockMessage.displayContent).thenReturn('Jag mår bra!');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show "Du:" prefix
        expect(find.text('Du: Jag mår bra!'), findsOneWidget);
      });

      testWidgets('shows sender name in group conversations',
          (WidgetTester tester) async {
        // ULTRATHINK: Test group message preview from lines 245-249
        when(() => mockConversation.isGroup).thenReturn(true);
        when(() => mockMessage.isFromCurrentUser(currentUserId)).thenReturn(false);
        when(() => mockMessage.senderDisplayName).thenReturn('Erik');
        when(() => mockMessage.displayContent).thenReturn('Ska vi ses imorgon?');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show sender name prefix
        expect(find.text('Erik: Ska vi ses imorgon?'), findsOneWidget);
      });

      testWidgets('shows system messages directly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test system message from lines 231-234
        when(() => mockMessage.isSystemMessage).thenReturn(true);
        when(() => mockMessage.content).thenReturn('Anna gick med i gruppen');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // System message shown directly
        expect(find.text('Anna gick med i gruppen'), findsOneWidget);
      });

      testWidgets('shows placeholder when no last message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty message from lines 223-227
        when(() => mockConversation.lastMessage).thenReturn(null);
        when(() => mockConversation.isGroup).thenReturn(false);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show default message for direct conversation
        expect(find.text('Säg hej!'), findsOneWidget);
      });

      testWidgets('shows group created message for empty groups',
          (WidgetTester tester) async {
        // ULTRATHINK: Test group created from lines 224-226
        when(() => mockConversation.lastMessage).thenReturn(null);
        when(() => mockConversation.isGroup).thenReturn(true);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show group created message
        expect(find.text('Grupp skapad'), findsOneWidget);
      });
    });

    group('Avatar Tests', () {
      testWidgets('shows initials fallback for users without avatar',
          (WidgetTester tester) async {
        // ULTRATHINK: Test avatar fallback from lines 199-208
        when(() => mockConversation.getDisplayAvatarUrl(any())).thenReturn(null);
        when(() => mockConversation.getDisplayTitle(any())).thenReturn('Johan');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show first letter
        expect(find.text('J'), findsOneWidget);
      });

      testWidgets('shows question mark for empty display names',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty name fallback from line 202
        when(() => mockConversation.getDisplayAvatarUrl(any())).thenReturn(null);
        when(() => mockConversation.getDisplayTitle(any())).thenReturn('');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show question mark
        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('handles Swedish characters in initials',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character handling
        when(() => mockConversation.getDisplayAvatarUrl(any())).thenReturn(null);
        when(() => mockConversation.getDisplayTitle(any())).thenReturn('Åsa');
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show Swedish character
        expect(find.text('Å'), findsOneWidget);
      });
    });

    group('Interaction Tests', () {
      testWidgets('handles tap callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test onTap from lines 40-41
        bool tapped = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        await tester.pump();
        
        expect(tapped, isTrue);
      });

      testWidgets('handles long press callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test onLongPress from line 42
        bool longPressed = false;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
              onLongPress: () {
                longPressed = true;
              },
            ),
          ),
        );

        await tester.longPress(find.byType(InkWell));
        await tester.pump();
        
        expect(longPressed, isTrue);
      });
    });

    group('Layout Tests', () {
      testWidgets('handles text overflow gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow from lines 74-75, 111-112
        final longTitle = 'A' * 100;
        final longMessage = 'B' * 200;
        
        when(() => mockConversation.getDisplayTitle(any())).thenReturn(longTitle);
        when(() => mockMessage.displayContent).thenReturn(longMessage);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Title text should have ellipsis
        final titleText = tester.widget<Text>(
          find.text(longTitle),
        );
        expect(titleText.overflow, equals(TextOverflow.ellipsis));
        expect(titleText.maxLines, equals(1));
        
        // Message text should have ellipsis
        final messageText = tester.widget<Text>(
          find.text(longMessage),
        );
        expect(messageText.overflow, equals(TextOverflow.ellipsis));
        expect(messageText.maxLines, equals(1));
      });

      testWidgets('maintains proper spacing between elements',
          (WidgetTester tester) async {
        // ULTRATHINK: Test spacing from lines 53, 79, 95, 117
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Check for SizedBox spacers
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SizedBox &&
                widget.width == AppDimensions.paddingM,
          ),
          findsWidgets,
        );
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null callbacks
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
              // No onTap or onLongPress provided
            ),
          ),
        );

        // Should render without errors
        expect(find.byType(ConversationListItem), findsOneWidget);
        
        // Tapping should not throw
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles conversation without participants gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test edge case handling
        when(() => mockConversation.getDisplayTitle(any())).thenReturn('');
        when(() => mockConversation.getDisplayAvatarUrl(any())).thenReturn(null);
        
        await tester.pumpWidget(
          createTestWidget(
            child: ConversationListItem(
              conversation: mockConversation,
              currentUserId: currentUserId,
            ),
          ),
        );

        // Should show question mark for empty name
        expect(find.text('?'), findsOneWidget);
      });
    });
  });
}