import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/messaging/message.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('Message', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final now = DateTime.now();
        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna Andersson',
          content: 'Hej! Hur mår du?',
          type: MessageType.text,
          status: MessageStatus.sending,
          sentAt: now,
        );

        expect(message.id, equals('msg_123'));
        expect(message.conversationId, equals('conv_456'));
        expect(message.senderId, equals('user_789'));
        expect(message.senderDisplayName, equals('Anna Andersson'));
        expect(message.senderAvatarUrl, isNull);
        expect(message.content, equals('Hej! Hur mår du?'));
        expect(message.type, equals(MessageType.text));
        expect(message.status, equals(MessageStatus.sending));
        expect(message.sentAt, equals(now));
        expect(message.deliveredAt, isNull);
        expect(message.readAt, isNull);
        expect(message.metadata, isNull);
        expect(message.replyToMessageId, isNull);
        expect(message.isEdited, isFalse);
        expect(message.editedAt, isNull);
      });

      test('should create with all parameters', () {
        final sentTime = DateTime(2024, 1, 15, 10, 30);
        final deliveredTime = DateTime(2024, 1, 15, 10, 31);
        final readTime = DateTime(2024, 1, 15, 10, 35);
        final editedTime = DateTime(2024, 1, 15, 11, 0);

        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna Andersson',
          senderAvatarUrl: 'https://example.com/avatar.jpg',
          content: 'Uppdaterat meddelande',
          type: MessageType.text,
          status: MessageStatus.read,
          sentAt: sentTime,
          deliveredAt: deliveredTime,
          readAt: readTime,
          metadata: {'customField': 'value'},
          replyToMessageId: 'parent_msg_123',
          isEdited: true,
          editedAt: editedTime,
        );

        expect(
          message.senderAvatarUrl,
          equals('https://example.com/avatar.jpg'),
        );
        expect(message.deliveredAt, equals(deliveredTime));
        expect(message.readAt, equals(readTime));
        expect(message.metadata!['customField'], equals('value'));
        expect(message.replyToMessageId, equals('parent_msg_123'));
        expect(message.isEdited, isTrue);
        expect(message.editedAt, equals(editedTime));
      });

      test('should handle different message types', () {
        final textMsg = Message(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Text',
          type: MessageType.text,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        final recipeMsg = Message(
          id: 'msg_2',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Recipe share',
          type: MessageType.recipeShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: {'recipeId': 'recipe_123', 'recipeTitle': 'Köttbullar'},
        );

        final systemMsg = Message(
          id: 'msg_3',
          conversationId: 'conv_1',
          senderId: 'system',
          senderDisplayName: 'System',
          content: 'User joined',
          type: MessageType.system,
          status: MessageStatus.delivered,
          sentAt: DateTime.now(),
        );

        expect(textMsg.type, equals(MessageType.text));
        expect(recipeMsg.type, equals(MessageType.recipeShare));
        expect(systemMsg.type, equals(MessageType.system));
      });

      test('should handle Swedish characters in content', () {
        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Åsa Öström',
          content: 'Jättegott med köttbullar och lingonsylt!',
          type: MessageType.text,
          status: MessageStatus.sending,
          sentAt: DateTime.now(),
        );

        expect(message.senderDisplayName, equals('Åsa Öström'));
        expect(message.content, contains('Jättegott'));
        expect(message.content, contains('köttbullar'));
        expect(message.content, contains('lingonsylt'));
      });
    });

    group('Factory Methods', () {
      test('should create text message', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna Andersson',
          senderAvatarUrl: 'https://example.com/avatar.jpg',
          content: 'Hej! Hur mår du?',
          replyToMessageId: 'parent_123',
        );

        expect(message.id, isNotEmpty);
        expect(message.id.length, equals(36)); // UUID v4 length
        expect(message.conversationId, equals('conv_456'));
        expect(message.senderId, equals('user_789'));
        expect(message.senderDisplayName, equals('Anna Andersson'));
        expect(
          message.senderAvatarUrl,
          equals('https://example.com/avatar.jpg'),
        );
        expect(message.content, equals('Hej! Hur mår du?'));
        expect(message.type, equals(MessageType.text));
        expect(message.status, equals(MessageStatus.sending));
        expect(message.sentAt, isNotNull);
        expect(message.replyToMessageId, equals('parent_123'));
      });

      test('should create recipe share message', () {
        final message = Message.recipeShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          recipeId: 'recipe_123',
          recipeTitle: 'Mormors köttbullar',
          message: 'Provade detta igår!',
        );

        expect(message.type, equals(MessageType.recipeShare));
        expect(message.content, equals('Provade detta igår!'));
        expect(message.metadata!['recipeId'], equals('recipe_123'));
        expect(message.metadata!['recipeTitle'], equals('Mormors köttbullar'));
      });

      test('should create recipe share with default message', () {
        final message = Message.recipeShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          recipeId: 'recipe_123',
          recipeTitle: 'Pannkakor',
        );

        expect(message.content, equals('Delade ett recept: Pannkakor'));
      });

      test('should create menu share message', () {
        final message = Message.menuShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Erik',
          menuId: 'menu_123',
          menuTitle: 'Veckans middagar',
          message: 'Här är vår planering!',
        );

        expect(message.type, equals(MessageType.menuShare));
        expect(message.content, equals('Här är vår planering!'));
        expect(message.metadata!['menuId'], equals('menu_123'));
        expect(message.metadata!['menuTitle'], equals('Veckans middagar'));
      });

      test('should create menu share with default message', () {
        final message = Message.menuShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Erik',
          menuId: 'menu_123',
          menuTitle: 'Helgmeny',
        );

        expect(message.content, equals('Delade en meny: Helgmeny'));
      });

      test('should create shopping list share message', () {
        final message = Message.shoppingListShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Maria',
          listId: 'list_123',
          listTitle: 'ICA-listan',
          message: 'Vi behöver handla detta!',
        );

        expect(message.type, equals(MessageType.shoppingListShare));
        expect(message.content, equals('Vi behöver handla detta!'));
        expect(message.metadata!['listId'], equals('list_123'));
        expect(message.metadata!['listTitle'], equals('ICA-listan'));
      });

      test('should create shopping list share with default message', () {
        final message = Message.shoppingListShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Maria',
          listId: 'list_123',
          listTitle: 'Veckans inköp',
        );

        expect(message.content, equals('Delade en inköpslista: Veckans inköp'));
      });

      test('should create system message', () {
        final message = Message.system(
          conversationId: 'conv_456',
          content: 'Erik Svensson har anslutit sig',
        );

        expect(message.id, isNotEmpty);
        expect(message.senderId, equals('system'));
        expect(message.senderDisplayName, equals('System'));
        expect(message.content, equals('Erik Svensson har anslutit sig'));
        expect(message.type, equals(MessageType.system));
        expect(message.status, equals(MessageStatus.delivered));
        expect(message.sentAt, isNotNull);
      });

      test('should generate unique IDs for factory methods', () {
        final msg1 = Message.text(
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Test',
        );

        final msg2 = Message.text(
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Test',
        );

        expect(msg1.id, isNot(equals(msg2.id)));
        expect(msg1.id.length, equals(36));
        expect(msg2.id.length, equals(36));
      });
    });

    group('Delivery Status', () {
      late Message message;

      setUp(() {
        message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test message',
        );
      });

      test('should track delivery progression', () {
        expect(message.status, equals(MessageStatus.sending));
        expect(message.isDelivered, isFalse);
        expect(message.isRead, isFalse);

        final sent = message.copyWith(status: MessageStatus.sent);
        expect(sent.status, equals(MessageStatus.sent));
        expect(sent.isDelivered, isFalse);
        expect(sent.isRead, isFalse);

        final delivered = sent.copyWith(
          status: MessageStatus.delivered,
          deliveredAt: DateTime.now(),
        );
        expect(delivered.status, equals(MessageStatus.delivered));
        expect(delivered.isDelivered, isTrue);
        expect(delivered.isRead, isFalse);

        final read = delivered.copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );
        expect(read.status, equals(MessageStatus.read));
        expect(read.isDelivered, isTrue);
        expect(read.isRead, isTrue);
      });

      test('should handle failed status', () {
        final failed = message.copyWith(status: MessageStatus.failed);

        expect(failed.status, equals(MessageStatus.failed));
        expect(failed.isDelivered, isFalse);
        expect(failed.isRead, isFalse);
      });

      test('should track timestamps', () {
        final now = DateTime.now();
        final delivered = message.copyWith(
          status: MessageStatus.delivered,
          deliveredAt: now,
        );

        expect(delivered.deliveredAt, equals(now));
        expect(delivered.readAt, isNull);

        final readTime = now.add(Duration(minutes: 5));
        final read = delivered.copyWith(
          status: MessageStatus.read,
          readAt: readTime,
        );

        expect(read.deliveredAt, equals(now));
        expect(read.readAt, equals(readTime));
      });

      test('should consider read implies delivered', () {
        final read = message.copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );

        expect(read.isRead, isTrue);
        expect(read.isDelivered, isTrue); // Read implies delivered
      });
    });

    group('Reply Functionality', () {
      test('should create reply message', () {
        final original = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'Original message',
        );

        final reply = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_2',
          senderDisplayName: 'Erik',
          content: 'This is a reply',
          replyToMessageId: original.id,
        );

        expect(reply.replyToMessageId, equals(original.id));
        expect(reply.isReply, isTrue);
      });

      test('should identify non-reply messages', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'Regular message',
        );

        expect(message.replyToMessageId, isNull);
        expect(message.isReply, isFalse);
      });

      test('should handle reply chains', () {
        final msg1 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_1',
          senderDisplayName: 'User 1',
          content: 'First message',
        );

        final msg2 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_2',
          senderDisplayName: 'User 2',
          content: 'Reply to first',
          replyToMessageId: msg1.id,
        );

        final msg3 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_3',
          senderDisplayName: 'User 3',
          content: 'Reply to second',
          replyToMessageId: msg2.id,
        );

        expect(msg2.replyToMessageId, equals(msg1.id));
        expect(msg3.replyToMessageId, equals(msg2.id));
      });
    });

    group('Edit Capabilities', () {
      late Message message;

      setUp(() {
        message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Original text',
        );
      });

      test('should edit message content', () {
        final edited = message.copyWith(
          content: 'Edited text',
          isEdited: true,
          editedAt: DateTime.now(),
        );

        expect(edited.content, equals('Edited text'));
        expect(edited.isEdited, isTrue);
        expect(edited.editedAt, isNotNull);
        expect(edited.id, equals(message.id)); // ID unchanged
      });

      test('should track edit timestamp', () {
        final editTime = DateTime(2024, 1, 15, 12, 0);
        final edited = message.copyWith(
          content: 'Updated',
          isEdited: true,
          editedAt: editTime,
        );

        expect(edited.editedAt, equals(editTime));
        expect(edited.isEdited, isTrue);
      });

      test('should handle multiple edits', () {
        var edited = message;

        for (int i = 1; i <= 3; i++) {
          edited = edited.copyWith(
            content: 'Edit $i',
            isEdited: true,
            editedAt: DateTime.now().add(Duration(minutes: i)),
          );

          expect(edited.content, equals('Edit $i'));
          expect(edited.isEdited, isTrue);
        }
      });
    });

    group('Display Methods', () {
      test('should format text message display', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Hej! Hur mår du?',
        );

        expect(message.displayContent, equals('Hej! Hur mår du?'));
      });

      test('should format recipe share display', () {
        final message = Message.recipeShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          recipeId: 'recipe_123',
          recipeTitle: 'Köttbullar',
        );

        expect(message.displayContent, equals('🍽️ Köttbullar'));
      });

      test('should format menu share display', () {
        final message = Message.menuShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Erik',
          menuId: 'menu_123',
          menuTitle: 'Veckans meny',
        );

        expect(message.displayContent, equals('📋 Veckans meny'));
      });

      test('should format shopping list share display', () {
        final message = Message.shoppingListShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Maria',
          listId: 'list_123',
          listTitle: 'ICA-listan',
        );

        expect(message.displayContent, equals('🛒 ICA-listan'));
      });

      test('should format system message display', () {
        final message = Message.system(
          conversationId: 'conv_456',
          content: 'Erik har anslutit sig',
        );

        expect(message.displayContent, equals('Erik har anslutit sig'));
      });

      test('should handle missing metadata gracefully', () {
        final recipeMsg = Message(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Recipe',
          type: MessageType.recipeShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: {}, // Empty metadata
        );

        expect(recipeMsg.displayContent, equals('🍽️ Recept'));

        final menuMsg = Message(
          id: 'msg_2',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'Menu',
          type: MessageType.menuShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          // No metadata at all
        );

        expect(menuMsg.displayContent, equals('📋 Meny'));
      });

      test('should format image message display', () {
        final message = Message(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'image.jpg',
          type: MessageType.image,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        expect(message.displayContent, equals('📷 Bild'));
      });

      test('should format voice message display', () {
        final message = Message(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderId: 'user_1',
          senderDisplayName: 'User',
          content: 'voice.m4a',
          type: MessageType.voice,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        expect(message.displayContent, equals('🎤 Röstmeddelande'));
      });
    });

    group('State Validation', () {
      test('should identify current user messages', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'My message',
        );

        expect(message.isFromCurrentUser('user_789'), isTrue);
        expect(message.isFromCurrentUser('user_999'), isFalse);
      });

      test('should identify system messages', () {
        final systemMsg = Message.system(
          conversationId: 'conv_456',
          content: 'User joined',
        );

        final textMsg = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Regular message',
        );

        expect(systemMsg.isSystemMessage, isTrue);
        expect(textMsg.isSystemMessage, isFalse);
      });

      test('should track read status', () {
        final unread = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test',
        );

        expect(unread.isRead, isFalse);

        final read = unread.copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );

        expect(read.isRead, isTrue);
      });

      test('should track delivery status', () {
        final sending = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test',
        );

        expect(sending.isDelivered, isFalse);

        final delivered = sending.copyWith(
          status: MessageStatus.delivered,
          deliveredAt: DateTime.now(),
        );

        expect(delivered.isDelivered, isTrue);
      });
    });

    group('copyWith Operations', () {
      late Message original;

      setUp(() {
        original = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Original content',
        );
      });

      test('should update status', () {
        final updated = original.copyWith(
          status: MessageStatus.delivered,
        );

        expect(updated.status, equals(MessageStatus.delivered));
        expect(updated.content, equals(original.content));
        expect(updated.id, equals(original.id));
      });

      test('should update timestamps', () {
        final now = DateTime.now();
        final updated = original.copyWith(
          deliveredAt: now,
          readAt: now.add(Duration(minutes: 5)),
        );

        expect(updated.deliveredAt, equals(now));
        expect(updated.readAt, equals(now.add(Duration(minutes: 5))));
      });

      test('should update metadata', () {
        final updated = original.copyWith(
          metadata: {'key': 'value', 'number': 42},
        );

        expect(updated.metadata!['key'], equals('value'));
        expect(updated.metadata!['number'], equals(42));
      });

      test('should preserve immutability', () {
        final updated = original.copyWith(
          content: 'New content',
        );

        expect(original.content, equals('Original content'));
        expect(updated.content, equals('New content'));
        expect(original.id, equals(updated.id));
      });
    });

    // Note: MessageType and MessageStatus extensions are tested through displayContent method
    // since the extensions are defined in message_type.dart and imported by message.dart

    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final msg1 = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Content 1',
          type: MessageType.text,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        final msg2 = Message(
          id: 'msg_123',
          conversationId: 'conv_999',
          senderId: 'user_999',
          senderDisplayName: 'Erik',
          content: 'Content 2',
          type: MessageType.recipeShare,
          status: MessageStatus.delivered,
          sentAt: DateTime.now(),
        );

        expect(msg1, equals(msg2));
        expect(msg1.hashCode, equals(msg2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final msg1 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Same content',
        );

        final msg2 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Same content',
        );

        expect(msg1, isNot(equals(msg2)));
      });

      test('should be equal to itself', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test',
        );

        expect(message, equals(message));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final sentTime = DateTime(2024, 1, 15, 10, 30);
        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test message content',
          type: MessageType.text,
          status: MessageStatus.delivered,
          sentAt: sentTime,
        );

        final str = message.toString();

        expect(str, contains('msg_123'));
        expect(str, contains('MessageType.text'));
        expect(str, contains('Test message content'));
        expect(str, contains('MessageStatus.delivered'));
        expect(str, contains(sentTime.toString()));
      });
    });

    group('Edge Cases', () {
      test('should handle very long content', () {
        final longContent = 'A' * 10000;
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: longContent,
        );

        expect(message.content, equals(longContent));
        expect(message.content.length, equals(10000));
      });

      test('should handle empty content', () {
        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: '',
          type: MessageType.text,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );

        expect(message.content, isEmpty);
        expect(message.displayContent, isEmpty);
      });

      test('should handle Swedish characters throughout', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Åsa Öström',
          content: 'Jättegott med köttbullar, lingonsylt och gräddsås!',
        );

        expect(message.senderDisplayName, equals('Åsa Öström'));
        expect(message.content, contains('Jättegott'));
        expect(message.content, contains('köttbullar'));
        expect(message.content, contains('lingonsylt'));
        expect(message.content, contains('gräddsås'));
      });

      test('should handle emoji in content', () {
        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna 😊',
          content: 'Fantastiskt recept! 🍽️ 😋 👍',
        );

        expect(message.senderDisplayName, contains('😊'));
        expect(message.content, contains('🍽️'));
        expect(message.content, contains('😋'));
        expect(message.content, contains('👍'));
      });

      test('should handle null avatar URLs', () {
        final message1 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          senderAvatarUrl: null,
          content: 'Test',
        );

        expect(message1.senderAvatarUrl, isNull);

        final message2 = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test',
        );

        expect(message2.senderAvatarUrl, isNull);
      });

      test('should handle complex metadata', () {
        final message = Message(
          id: 'msg_123',
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Complex message',
          type: MessageType.recipeShare,
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
          metadata: {
            'recipeId': 'recipe_123',
            'recipeTitle': 'Köttbullar',
            'servings': 4,
            'cookingTime': 45,
            'difficulty': 'medium',
            'tags': ['swedish', 'meat', 'traditional'],
            'nested': {
              'author': 'Mormor',
              'year': 1950,
            },
          },
        );

        expect(message.metadata!['recipeId'], equals('recipe_123'));
        expect(message.metadata!['servings'], equals(4));
        expect(message.metadata!['tags'], contains('swedish'));
        expect(message.metadata!['nested']['author'], equals('Mormor'));
      });

      test('should handle self-replies', () {
        final original = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Original message',
        );

        final selfReply = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789', // Same sender
          senderDisplayName: 'Anna',
          content: 'Adding to my previous message',
          replyToMessageId: original.id,
        );

        expect(selfReply.senderId, equals(original.senderId));
        expect(selfReply.replyToMessageId, equals(original.id));
        expect(selfReply.isReply, isTrue);
      });

      test('should handle rapid status changes', () {
        var message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: 'Test',
        );

        // Simulate rapid status updates
        final statuses = [
          MessageStatus.sending,
          MessageStatus.sent,
          MessageStatus.delivered,
          MessageStatus.read,
        ];

        for (final status in statuses) {
          message = message.copyWith(status: status);
          expect(message.status, equals(status));
        }
      });

      test('should handle whitespace in content', () {
        final contentWithWhitespace = '''
First line
  Indented line
    More indentation
      
Last line with spaces    ''';

        final message = Message.text(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          content: contentWithWhitespace,
        );

        expect(message.content, equals(contentWithWhitespace));
        expect(message.displayContent, equals(contentWithWhitespace));
      });

      test('should handle special characters in metadata', () {
        final message = Message.recipeShare(
          conversationId: 'conv_456',
          senderId: 'user_789',
          senderDisplayName: 'Anna',
          recipeId: 'recipe_123',
          recipeTitle: 'Räksmörgås à la "Skagen"',
        );

        expect(
          message.metadata!['recipeTitle'],
          equals('Räksmörgås à la "Skagen"'),
        );
        expect(message.displayContent, equals('🍽️ Räksmörgås à la "Skagen"'));
      });
    });
  });
}
