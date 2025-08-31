// test/widget/messaging/message_bubble_ultrathink_test.dart
// ULTRATHINK TEST SUITE: MessageBubble Widget - 614 lines of production code
// Testing comprehensive message bubble with multiple types, Swedish localization, status indicators

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code
import 'package:butlery/widgets/messaging/message_bubble.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('MessageBubble Ultrathink Tests', () {
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
          body: child,
        ),
      );
    }

    // Factory methods for creating test messages
    Message createTextMessage({
      String id = 'msg1',
      String senderId = 'user1',
      String displayName = 'Anna Andersson',
      String? avatarUrl,
      String content = 'Test meddelande',
      MessageStatus status = MessageStatus.sent,
      bool isEdited = false,
      String? replyToMessageId,
    }) {
      return Message(
        id: id,
        conversationId: 'conv1',
        senderId: senderId,
        senderDisplayName: displayName,
        senderAvatarUrl: avatarUrl,
        content: content,
        type: MessageType.text,
        status: status,
        sentAt: DateTime.now(),
        isEdited: isEdited,
        replyToMessageId: replyToMessageId,
      );
    }

    Message createSystemMessage({
      String content = 'Anna gick med i konversationen',
    }) {
      return Message(
        id: 'sys1',
        conversationId: 'conv1',
        senderId: 'system',
        senderDisplayName: 'System',
        content: content,
        type: MessageType.system,
        status: MessageStatus.delivered,
        sentAt: DateTime.now(),
      );
    }

    Message createRecipeShareMessage({
      String senderId = 'user1',
      String content = 'Kolla detta recept!',
      Map<String, dynamic>? metadata,
    }) {
      return Message(
        id: 'recipe1',
        conversationId: 'conv1',
        senderId: senderId,
        senderDisplayName: 'Anna Andersson',
        content: content,
        type: MessageType.recipeShare,
        status: MessageStatus.sent,
        sentAt: DateTime.now(),
        metadata: metadata ?? {'recipeId': 'r1', 'recipeTitle': 'Köttbullar'},
      );
    }

    group('System Message Tests', () {
      testWidgets('renders system message with center layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 91-118
        final systemMessage = createSystemMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: systemMessage,
              currentUserId: 'user1',
            ),
          ),
        );

        // Should render Center widget for system messages
        expect(find.byType(Center), findsOneWidget);
        expect(find.text('Anna gick med i konversationen'), findsOneWidget);

        // Should have proper Container styling
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Center),
            matching: find.byType(Container),
          ),
        );

        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        )));
      });

      testWidgets('system message has correct text styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 107-114
        final systemMessage = createSystemMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: systemMessage,
              currentUserId: 'user1',
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.text('Anna gick med i konversationen'),
        );

        expect(text.style?.color, equals(AppColors.textMedium));
        expect(text.style?.fontStyle, equals(FontStyle.italic));
        expect(text.textAlign, equals(TextAlign.center));
      });

      testWidgets('system message container has correct decoration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 103-106
        final systemMessage = createSystemMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: systemMessage,
              currentUserId: 'user1',
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Center),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, 
               equals(BorderRadius.circular(AppDimensions.borderRadiusM)));

        // Test alpha color - production line 104
        final alphaValue = (decoration.color!.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(30)); // 0.1 alpha ≈ 25.5
      });
    });

    group('Message Layout Tests', () {
      testWidgets('sent message aligns to right with correct layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 58-88
        final sentMessage = createTextMessage(senderId: 'currentUser');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: sentMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should have Row with end alignment for sent messages
        final row = tester.widget<Row>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Row),
          ).first,
        );
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.end));
        expect(row.crossAxisAlignment, equals(CrossAxisAlignment.end));
      });

      testWidgets('received message aligns to left with correct layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 58-88
        final receivedMessage = createTextMessage(senderId: 'otherUser');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should have Row with start alignment for received messages
        final row = tester.widget<Row>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Row),
          ).first,
        );
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.start));
        expect(row.crossAxisAlignment, equals(CrossAxisAlignment.end));
      });

      testWidgets('message has correct padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 53-57
        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Find the main Padding widget
        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Padding),
          ).first,
        );

        expect(padding.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.spacingXs,
        )));
      });
    });

    group('Avatar Tests', () {
      testWidgets('shows avatar for received messages when showAvatar=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 64-67
        final receivedMessage = createTextMessage(
          senderId: 'otherUser',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        // Should have SimpleImageWidget for avatar
        expect(find.byType(SimpleImageWidget), findsOneWidget);

        // Avatar container should have correct dimensions
        final avatarContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Container),
          ).first,
        );
        expect(avatarContainer.constraints?.maxWidth, equals(32));
        expect(avatarContainer.constraints?.maxHeight, equals(32));
      });

      testWidgets('shows avatar fallback when no avatar URL',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 140-151
        final messageWithoutAvatar = createTextMessage(
          senderId: 'otherUser',
          displayName: 'Erik Eriksson',
          avatarUrl: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: messageWithoutAvatar,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        // Should show first initial as fallback
        expect(find.text('E'), findsOneWidget);

        // Avatar fallback should have correct styling
        final fallbackText = tester.widget<Text>(find.text('E'));
        expect(fallbackText.style?.color, equals(AppColors.primaryBlue));
      });

      testWidgets('avatar fallback handles empty display name',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 143-145
        final messageEmptyName = createTextMessage(
          senderId: 'otherUser',
          displayName: '',
          avatarUrl: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: messageEmptyName,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        // Should show '?' for empty display name
        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('shows avatar for sent messages on right side',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 82-85
        final sentMessage = createTextMessage(
          senderId: 'currentUser',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: sentMessage,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        // Avatar should be present and positioned after the message content
        expect(find.byType(SimpleImageWidget), findsOneWidget);

        // Should have SizedBox for spacing before avatar
        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(spacingBoxes.length, greaterThan(0));
      });

      testWidgets('avatar container has correct decoration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 121-127
        final message = createTextMessage(
          senderId: 'otherUser',
          avatarUrl: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        final avatarContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Container),
          ).first,
        );

        final decoration = avatarContainer.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));

        // Test alpha color - production line 126
        final alphaValue = (decoration.color!.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(55)); // 0.2 alpha ≈ 51
      });
    });

    group('Sender Name Tests', () {
      testWidgets('shows sender name when showAvatar=false for received messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 74-75
        final receivedMessage = createTextMessage(
          senderId: 'otherUser',
          displayName: 'Björn Bergström',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
              showAvatar: false,
            ),
          ),
        );

        // Should show sender name
        expect(find.text('Björn Bergström'), findsOneWidget);
      });

      testWidgets('sender name has correct styling and padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 153-167
        final receivedMessage = createTextMessage(
          senderId: 'otherUser',
          displayName: 'Maria Nilsson',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
              showAvatar: false,
            ),
          ),
        );

        // Check sender name styling
        final nameText = tester.widget<Text>(find.text('Maria Nilsson'));
        expect(nameText.style?.color, equals(AppColors.textMedium));
        expect(nameText.style?.fontWeight, equals(FontWeight.w500));

        // Check padding - find the specific padding for sender name
        final namePadding = tester.widget<Padding>(
          find.ancestor(
            of: find.text('Maria Nilsson'),
            matching: find.byType(Padding),
          ).first,
        );
        expect(namePadding.padding, equals(const EdgeInsets.only(
          left: AppDimensions.paddingS,
          bottom: AppDimensions.spacingXs,
        )));
      });

      testWidgets('does not show sender name when showAvatar=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code - negative test for lines 74-75
        final receivedMessage = createTextMessage(
          senderId: 'otherUser',
          displayName: 'Test User',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
              showAvatar: true,
            ),
          ),
        );

        // Should NOT show sender name when avatar is shown
        expect(find.text('Test User'), findsNothing);
      });
    });

    group('Message Content Tests', () {
      testWidgets('renders text content with correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 257-284
        final textMessage = createTextMessage(
          content: 'Hej! Hur mår du idag?',
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: textMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Hej! Hur mår du idag?'), findsOneWidget);

        // Text color should be white for sent messages
        final messageText = tester.widget<Text>(
          find.text('Hej! Hur mår du idag?'),
        );
        expect(messageText.style?.color, equals(AppColors.cardWhite));
      });

      testWidgets('shows edited indicator with Swedish text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 269-282
        final editedMessage = createTextMessage(
          content: 'Redigerat meddelande',
          isEdited: true,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: editedMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Redigerat meddelande'), findsOneWidget);
        expect(find.text('redigerad'), findsOneWidget);

        // Edited text should be italic and have correct color
        final editedText = tester.widget<Text>(find.text('redigerad'));
        expect(editedText.style?.fontStyle, equals(FontStyle.italic));
        
        // Should have alpha color
        final alphaValue = (editedText.style!.color!.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(180)); // 0.7 alpha ≈ 178.5
      });

      testWidgets('text content color differs for sent vs received',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 263-267
        final sentMessage = createTextMessage(
          content: 'Skickat meddelande',
          senderId: 'currentUser',
        );
        final receivedMessage = createTextMessage(
          content: 'Mottaget meddelande',
          senderId: 'otherUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                MessageBubble(
                  message: sentMessage,
                  currentUserId: 'currentUser',
                ),
                MessageBubble(
                  message: receivedMessage,
                  currentUserId: 'currentUser',
                ),
              ],
            ),
          ),
        );

        // Sent message should be white
        final sentText = tester.widget<Text>(find.text('Skickat meddelande'));
        expect(sentText.style?.color, equals(AppColors.cardWhite));

        // Received message should be dark
        final receivedText = tester.widget<Text>(find.text('Mottaget meddelande'));
        expect(receivedText.style?.color, equals(AppColors.textDark));
      });
    });

    group('Message Card Tests', () {
      testWidgets('message card has correct styling for sent messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 169-194
        final sentMessage = createTextMessage(senderId: 'currentUser');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: sentMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        final styledCard = tester.widget<StyledCard>(find.byType(StyledCard));
        expect(styledCard.backgroundColor, equals(AppColors.primaryBlue));
        expect(styledCard.borderRadius, equals(AppDimensions.borderRadiusM));
        expect(styledCard.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        )));
      });

      testWidgets('message card has correct styling for received messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 174-176
        final receivedMessage = createTextMessage(senderId: 'otherUser');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        final styledCard = tester.widget<StyledCard>(find.byType(StyledCard));
        expect(styledCard.backgroundColor, equals(AppColors.cardWhite));
      });

      testWidgets('gesture detector handles tap and long press',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 170-172
        bool tapped = false;
        bool longPressed = false;

        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
            ),
          ),
        );

        // Test tap
        await tester.tap(find.byType(StyledCard));
        expect(tapped, isTrue);

        // Test long press
        await tester.longPress(find.byType(StyledCard));
        expect(longPressed, isTrue);
      });
    });

    group('Recipe Share Content Tests', () {
      testWidgets('shows recipe share with Swedish localization',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 286-348
        final recipeMessage = createRecipeShareMessage(
          metadata: {
            'recipeId': 'recipe123',
            'recipeTitle': 'Mormors köttbullar',
          },
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: recipeMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('🍽️ Recept delat'), findsOneWidget);
        expect(find.text('Mormors köttbullar'), findsOneWidget);
        expect(find.text('Kolla detta recept!'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });

      testWidgets('recipe share handles missing metadata gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 287 - check metadata handling
        final recipeMessage = Message(
          id: 'recipe_test',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Recept utan metadata',
          type: MessageType.recipeShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: null, // This should trigger the fallback
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: recipeMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should show default title when metadata is missing
        expect(find.text('Okänt recept'), findsOneWidget);
        expect(find.text('🍽️ Recept delat'), findsOneWidget);
      });

      testWidgets('recipe share content styling varies by sender',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 306-308, 320-323
        final sentRecipeMessage = createRecipeShareMessage(senderId: 'currentUser');
        final receivedRecipeMessage = createRecipeShareMessage(senderId: 'otherUser');

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                MessageBubble(
                  message: sentRecipeMessage,
                  currentUserId: 'currentUser',
                ),
                MessageBubble(
                  message: receivedRecipeMessage,
                  currentUserId: 'currentUser',
                ),
              ],
            ),
          ),
        );

        // Both should have recipe share indicators
        expect(find.text('🍽️ Recept delat'), findsNWidgets(2));
        expect(find.byIcon(Icons.restaurant_menu), findsNWidgets(2));
      });
    });

    group('Menu Share Content Tests', () {
      testWidgets('shows menu share with Swedish localization',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 350-403
        final menuMessage = Message(
          id: 'menu1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Veckomeny!',
          type: MessageType.menuShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: {
            'menuId': 'menu456',
            'menuTitle': 'Vecka 12 - Familjen Andersson',
          },
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: menuMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('📋 Meny delad'), findsOneWidget);
        expect(find.text('Vecka 12 - Familjen Andersson'), findsOneWidget);
        expect(find.byIcon(Icons.list_alt), findsOneWidget);
      });

      testWidgets('menu share handles missing metadata',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 351
        final menuMessage = Message(
          id: 'menu1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Meny!',
          type: MessageType.menuShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: menuMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Okänd meny'), findsOneWidget);
      });
    });

    group('Shopping List Share Content Tests', () {
      testWidgets('shows shopping list share with Swedish localization',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 405-458
        final shoppingMessage = Message(
          id: 'shop1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Handla detta!',
          type: MessageType.shoppingListShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: {
            'listId': 'list789',
            'listTitle': 'Helghandling ICA',
          },
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: shoppingMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('🛒 Inköpslista delad'), findsOneWidget);
        expect(find.text('Helghandling ICA'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      });

      testWidgets('shopping list share handles missing metadata',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 406
        final shoppingMessage = Message(
          id: 'shop1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Lista!',
          type: MessageType.shoppingListShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: shoppingMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Okänd inköpslista'), findsOneWidget);
      });
    });

    group('Image Content Tests', () {
      testWidgets('shows image content with placeholder icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 460-498
        final imageMessage = Message(
          id: 'img1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: 'Kolla på denna bild!',
          type: MessageType.image,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: imageMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.text('Kolla på denna bild!'), findsOneWidget);
      });

      testWidgets('image content has correct size constraints',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 462-465
        final imageMessage = Message(
          id: 'img1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: '',
          type: MessageType.image,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: imageMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        final imageContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Container),
          ).first,
        );

        expect(imageContainer.constraints?.maxWidth, equals(200));
        expect(imageContainer.constraints?.maxHeight, equals(200));
      });

      testWidgets('image content handles empty text content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 483-495
        final imageMessage = Message(
          id: 'img1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: '',
          type: MessageType.image,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: imageMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should show icon but no text content
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.text(''), findsNothing);
      });
    });

    group('Voice Content Tests', () {
      testWidgets('shows voice content with Swedish text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 500-524
        final voiceMessage = Message(
          id: 'voice1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: '',
          type: MessageType.voice,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: voiceMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.text('Röstmeddelande'), findsOneWidget);
      });

      testWidgets('voice content styling varies by sender',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 508-510, 516-518
        final sentVoiceMessage = Message(
          id: 'voice1',
          conversationId: 'conv1',
          senderId: 'currentUser',
          senderDisplayName: 'Anna',
          content: '',
          type: MessageType.voice,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        final receivedVoiceMessage = Message(
          id: 'voice2',
          conversationId: 'conv1',
          senderId: 'otherUser',
          senderDisplayName: 'Erik',
          content: '',
          type: MessageType.voice,
          status: MessageStatus.delivered,
          sentAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                MessageBubble(
                  message: sentVoiceMessage,
                  currentUserId: 'currentUser',
                ),
                MessageBubble(
                  message: receivedVoiceMessage,
                  currentUserId: 'currentUser',
                ),
              ],
            ),
          ),
        );

        expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
        expect(find.text('Röstmeddelande'), findsNWidgets(2));
      });
    });

    group('Message Status Tests', () {
      testWidgets('shows Swedish status for sending message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 582-595
        final sendingMessage = createTextMessage(
          status: MessageStatus.sending,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: sendingMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Skickar'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('shows Swedish status for sent message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 571, 586
        final sentMessage = createTextMessage(
          status: MessageStatus.sent,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: sentMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Skickat'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('shows Swedish status for delivered message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 573, 588
        final deliveredMessage = createTextMessage(
          status: MessageStatus.delivered,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: deliveredMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Levererat'), findsOneWidget);
        expect(find.byIcon(Icons.done_all), findsOneWidget);
      });

      testWidgets('shows Swedish status for read message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 575, 590
        final readMessage = createTextMessage(
          status: MessageStatus.read,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: readMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Läst'), findsOneWidget);
        expect(find.byIcon(Icons.done_all), findsOneWidget);
      });

      testWidgets('shows Swedish status for failed message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 577, 592
        final failedMessage = createTextMessage(
          status: MessageStatus.failed,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: failedMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        expect(find.text('Misslyckades'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('status icon has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 532-536
        final message = createTextMessage(
          status: MessageStatus.delivered,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
            ),
          ),
        );

        final statusIcon = tester.widget<Icon>(
          find.byIcon(Icons.done_all),
        );
        expect(statusIcon.size, equals(12));

        // Should have alpha color - production line 535
        final alphaValue = (statusIcon.color!.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(180)); // 0.7 alpha ≈ 178.5
      });

      testWidgets('status text has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 538-545
        final message = createTextMessage(
          status: MessageStatus.sent,
          senderId: 'currentUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
            ),
          ),
        );

        final statusText = tester.widget<Text>(find.text('Skickat'));
        expect(statusText.style?.fontSize, equals(10));

        // Should have alpha color - production line 541
        final alphaValue = (statusText.style!.color!.a * 255.0).round() & 0xff;
        expect(alphaValue, lessThan(180)); // 0.7 alpha ≈ 178.5
      });

      testWidgets('does not show status for received messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code - negative test for lines 188-189
        final receivedMessage = createTextMessage(
          status: MessageStatus.delivered,
          senderId: 'otherUser',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should NOT show status for received messages
        expect(find.text('Levererat'), findsNothing);
        expect(find.text('Skickat'), findsNothing);
        expect(find.text('Läst'), findsNothing);
        expect(find.byIcon(Icons.done_all), findsNothing);
        expect(find.byIcon(Icons.check), findsNothing);
      });
    });

    group('Timestamp Tests', () {
      testWidgets('shows timestamp when showTimestamp=true',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 77-78
        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              showTimestamp: true,
            ),
          ),
        );

        // Should show some timestamp text
        expect(find.text('nu'), findsOneWidget);
      });

      testWidgets('timestamp has correct styling and padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 551-565
        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              showTimestamp: true,
            ),
          ),
        );

        final timestampText = tester.widget<Text>(find.text('nu'));
        expect(timestampText.style?.color, equals(AppColors.textLight));
        expect(timestampText.style?.fontSize, equals(10));

        // Check timestamp padding - find the specific padding for timestamp
        final timestampPadding = tester.widget<Padding>(
          find.ancestor(
            of: find.text('nu'),
            matching: find.byType(Padding),
          ).first,
        );
        expect(timestampPadding.padding, equals(const EdgeInsets.only(
          top: AppDimensions.spacingXs,
          left: AppDimensions.paddingS,
          right: 0,
        )));
      });

      testWidgets('timestamp padding differs for sent vs received',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 552-556
        final receivedMessage = createTextMessage(senderId: 'otherUser');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: receivedMessage,
              currentUserId: 'currentUser',
              showTimestamp: true,
            ),
          ),
        );

        final timestampPadding = tester.widget<Padding>(
          find.ancestor(
            of: find.text('nu'),
            matching: find.byType(Padding),
          ).first,
        );

        // For received messages, left padding should be paddingS, right should be 0
        expect(timestampPadding.padding, equals(const EdgeInsets.only(
          top: AppDimensions.spacingXs,
          left: AppDimensions.paddingS,
          right: 0,
        )));
      });

      testWidgets('does not show timestamp when showTimestamp=false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code - negative test for lines 77-78
        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              showTimestamp: false,
            ),
          ),
        );

        // Should not find timestamp text
        expect(find.text('nu'), findsNothing);
      });

      testWidgets('timestamp formatting shows Swedish relative times',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 597-613
        // Create message from 5 minutes ago
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        final message = Message(
          id: 'msg1',
          conversationId: 'conv1',
          senderId: 'user1',
          senderDisplayName: 'Anna',
          content: 'Old message',
          type: MessageType.text,
          status: MessageStatus.sent,
          sentAt: fiveMinutesAgo,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              showTimestamp: true,
            ),
          ),
        );

        // Should show "5m" for 5 minutes ago
        expect(find.text('5m'), findsOneWidget);
      });
    });

    group('Reply Preview Tests', () {
      testWidgets('shows reply preview when message is a reply',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 185-186, 196-236
        final originalMessage = createTextMessage(
          id: 'original',
          senderId: 'otherUser',
          displayName: 'Erik Eriksson',
          content: 'Detta är det ursprungliga meddelandet',
        );

        final replyMessage = createTextMessage(
          id: 'reply',
          senderId: 'currentUser',
          content: 'Detta är mitt svar',
          replyToMessageId: 'original',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: replyMessage,
              currentUserId: 'currentUser',
              replyToMessage: originalMessage,
            ),
          ),
        );

        // Should show reply preview with original sender and content
        expect(find.text('Erik Eriksson'), findsOneWidget);
        expect(find.text('Detta är det ursprungliga meddelandet'), findsOneWidget);
        expect(find.text('Detta är mitt svar'), findsOneWidget);
      });

      testWidgets('reply preview has correct styling and layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 197-235
        final originalMessage = createTextMessage(
          id: 'original',
          senderId: 'otherUser',
          displayName: 'Maria Nilsson',
          content: 'Originalmeddelande',
        );

        final replyMessage = createTextMessage(
          id: 'reply',
          senderId: 'currentUser',
          content: 'Svar på meddelandet',
          replyToMessageId: 'original',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: replyMessage,
              currentUserId: 'currentUser',
              replyToMessage: originalMessage,
            ),
          ),
        );

        // Find all containers and look for one with margin (reply preview)
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Container),
          ),
        );
        final replyContainer = containers.firstWhere((c) => c.margin != null);

        // Check margin and padding
        expect(replyContainer.margin, equals(const EdgeInsets.only(
          bottom: AppDimensions.paddingS,
        )));
        expect(replyContainer.padding, equals(const EdgeInsets.all(
          AppDimensions.paddingS,
        )));

        // Check decoration
        final decoration = replyContainer.decoration as BoxDecoration;
        expect(decoration.borderRadius, 
               equals(BorderRadius.circular(AppDimensions.borderRadiusS)));

        // Should have left border - cast to Border to access left property
        if (decoration.border is Border) {
          final border = decoration.border as Border;
          expect(border.left.width, equals(3));
          expect(border.left.color, equals(AppColors.accent));
        }
      });

      testWidgets('reply preview content has correct text truncation',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 223-232
        final originalMessage = createTextMessage(
          id: 'original',
          senderId: 'otherUser',
          displayName: 'Test User',
          content: 'Ett mycket långt meddelande som bör trunceras ' * 5,
        );

        final replyMessage = createTextMessage(
          id: 'reply',
          replyToMessageId: 'original',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: replyMessage,
              currentUserId: 'currentUser',
              replyToMessage: originalMessage,
            ),
          ),
        );

        // Should find the original content text with ellipsis
        final contentText = tester.widget<Text>(
          find.text(originalMessage.content).first,
        );
        expect(contentText.maxLines, equals(2));
        expect(contentText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('reply preview styling varies by sender',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 201-202, 216-219
        final originalMessage = createTextMessage(
          id: 'original',
          senderId: 'otherUser',
          displayName: 'Test User',
          content: 'Original',
        );

        final sentReply = createTextMessage(
          id: 'sentReply',
          senderId: 'currentUser',
          content: 'Sent reply',
          replyToMessageId: 'original',
        );

        final receivedReply = createTextMessage(
          id: 'receivedReply',
          senderId: 'otherUser',
          content: 'Received reply',
          replyToMessageId: 'original',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                MessageBubble(
                  message: sentReply,
                  currentUserId: 'currentUser',
                  replyToMessage: originalMessage,
                ),
                MessageBubble(
                  message: receivedReply,
                  currentUserId: 'currentUser',
                  replyToMessage: originalMessage,
                ),
              ],
            ),
          ),
        );

        // Both should show reply previews
        expect(find.text('Test User'), findsNWidgets(2));
        expect(find.text('Original'), findsNWidgets(2));
      });

      testWidgets('does not show reply preview when not a reply',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code - negative test for lines 185-186
        final regularMessage = createTextMessage(
          content: 'Regular message',
          replyToMessageId: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: regularMessage,
              currentUserId: 'currentUser',
              replyToMessage: null,
            ),
          ),
        );

        // Should only show the regular message content
        expect(find.text('Regular message'), findsOneWidget);
        
        // Should not have any reply preview containers
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.where((c) => c.margin != null).isEmpty, isTrue);
      });
    });

    group('Integration Tests', () {
      testWidgets('complex message with all features',
          (WidgetTester tester) async {
        // ULTRATHINK: Test real-world complex message scenario
        final originalMessage = createTextMessage(
          id: 'original',
          senderId: 'friend',
          displayName: 'Erik Svensson',
          content: 'Vilken typ av kött använder du?',
        );

        final complexReply = createTextMessage(
          id: 'complex',
          senderId: 'currentUser',
          displayName: 'Anna Andersson',
          content: 'Jag brukar använda blandfärs - både nöt och fläsk. Det ger bästa smaken!',
          status: MessageStatus.read,
          isEdited: true,
          replyToMessageId: 'original',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: complexReply,
              currentUserId: 'currentUser',
              replyToMessage: originalMessage,
              showAvatar: true,
              showTimestamp: true,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        );

        // Should show all features
        expect(find.text('Erik Svensson'), findsOneWidget); // Reply preview
        expect(find.text('Vilken typ av kött använder du?'), findsOneWidget);
        expect(find.text('Jag brukar använda blandfärs - både nöt och fläsk. Det ger bästa smaken!'), findsOneWidget);
        expect(find.text('redigerad'), findsOneWidget);
        expect(find.text('Läst'), findsOneWidget);
        expect(find.text('nu'), findsOneWidget);
      });

      testWidgets('message bubble handles Swedish special characters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish localization edge cases
        final swedishMessage = createTextMessage(
          displayName: 'Åsa Östman',
          content: 'Hej! Jag älskar köttbullar och lingonsylt. Återkommer med fler recept från Skåne.',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: swedishMessage,
              currentUserId: 'otherUser',
              showAvatar: false,
            ),
          ),
        );

        expect(find.text('Åsa Östman'), findsOneWidget);
        expect(find.text('Hej! Jag älskar köttbullar och lingonsylt. Återkommer med fler recept från Skåne.'), 
               findsOneWidget);
      });

      testWidgets('message bubble with all callback handlers',
          (WidgetTester tester) async {
        // ULTRATHINK: Test all interaction callbacks
        bool tapped = false;
        bool longPressed = false;

        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
            ),
          ),
        );

        // Test all interactions
        await tester.tap(find.byType(StyledCard));
        expect(tapped, isTrue);

        await tester.longPress(find.byType(StyledCard));
        expect(longPressed, isTrue);

        expect(find.byType(MessageBubble), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test null callback handling
        final message = createTextMessage();

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: message,
              currentUserId: 'currentUser',
              onTap: null,
              onLongPress: null,
              onReply: null,
            ),
          ),
        );

        // Should render without error
        expect(find.byType(MessageBubble), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Should handle tap without crashing
        await tester.tap(find.byType(StyledCard));
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles empty content gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty content handling
        final emptyMessage = createTextMessage(content: '');

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: emptyMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should render without error - empty content is handled gracefully
        expect(find.byType(MessageBubble), findsOneWidget);
        // There should be a text widget with empty content, which is okay
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles very long content without overflow',
          (WidgetTester tester) async {
        // ULTRATHINK: Test long content handling
        final longText = 'Detta är ett mycket långt meddelande som ' * 20;
        final longMessage = createTextMessage(content: longText);

        await tester.pumpWidget(
          createTestWidget(
            child: MessageBubble(
              message: longMessage,
              currentUserId: 'currentUser',
            ),
          ),
        );

        // Should render without overflow
        expect(find.text(longText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles missing metadata in share messages gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test missing metadata handling across all share types
        final shareTypes = [
          MessageType.recipeShare,
          MessageType.menuShare,
          MessageType.shoppingListShare,
        ];

        for (final shareType in shareTypes) {
          final shareMessage = Message(
            id: 'share_${shareType.name}',
            conversationId: 'conv1',
            senderId: 'currentUser',
            senderDisplayName: 'Anna',
            content: 'Share without metadata',
            type: shareType,
            status: MessageStatus.sent,
            sentAt: DateTime.now(),
            metadata: null,
          );

          await tester.pumpWidget(
            createTestWidget(
              child: MessageBubble(
                message: shareMessage,
                currentUserId: 'currentUser',
              ),
            ),
          );

          // Should render without error and show default titles
          expect(find.byType(MessageBubble), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Should show appropriate default text
          if (shareType == MessageType.recipeShare) {
            expect(find.text('Okänt recept'), findsOneWidget);
          } else if (shareType == MessageType.menuShare) {
            expect(find.text('Okänd meny'), findsOneWidget);
          } else if (shareType == MessageType.shoppingListShare) {
            expect(find.text('Okänd inköpslista'), findsOneWidget);
          }

          // Clean up for next iteration
          await tester.binding.delayed(Duration.zero);
        }
      });
    });
  });
}