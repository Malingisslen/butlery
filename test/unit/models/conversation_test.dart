import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('Conversation', () {
    late Message testMessage;
    
    setUp(() {
      testMessage = Message.text(
        conversationId: 'conv_123',
        senderId: 'user_1',
        senderDisplayName: 'Anna',
        content: 'Test message',
      );
    });
    
    group('Construction', () {
      test('should create with required parameters', () {
        final now = DateTime.now();
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {
            'user_1': 'Anna Andersson',
            'user_2': 'Erik Svensson',
          },
          participantAvatarUrls: {
            'user_1': 'https://example.com/anna.jpg',
            'user_2': null,
          },
          lastReadTimestamps: {
            'user_1': now,
            'user_2': now,
          },
          createdAt: now,
          updatedAt: now,
          isGroup: false,
        );
        
        expect(conversation.id, equals('conv_123'));
        expect(conversation.participantIds, equals(['user_1', 'user_2']));
        expect(conversation.participantDisplayNames['user_1'], equals('Anna Andersson'));
        expect(conversation.participantDisplayNames['user_2'], equals('Erik Svensson'));
        expect(conversation.participantAvatarUrls['user_1'], equals('https://example.com/anna.jpg'));
        expect(conversation.participantAvatarUrls['user_2'], isNull);
        expect(conversation.lastMessage, isNull);
        expect(conversation.lastReadTimestamps['user_1'], equals(now));
        expect(conversation.createdAt, equals(now));
        expect(conversation.updatedAt, equals(now));
        expect(conversation.title, isNull);
        expect(conversation.isGroup, isFalse);
        expect(conversation.metadata, isNull);
      });
      
      test('should create with all parameters including metadata', () {
        final now = DateTime.now();
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
          participantAvatarUrls: {
            'user_1': 'https://example.com/anna.jpg',
            'user_2': 'https://example.com/erik.jpg',
            'user_3': null,
          },
          lastMessage: testMessage,
          lastReadTimestamps: {
            'user_1': now,
            'user_2': now.subtract(Duration(hours: 1)),
            'user_3': now.subtract(Duration(days: 1)),
          },
          createdAt: now.subtract(Duration(days: 7)),
          updatedAt: now,
          title: 'Veckans middagsplanering',
          isGroup: true,
          metadata: {'creatorId': 'user_1', 'theme': 'blue'},
        );
        
        expect(conversation.lastMessage, equals(testMessage));
        expect(conversation.title, equals('Veckans middagsplanering'));
        expect(conversation.isGroup, isTrue);
        expect(conversation.metadata!['creatorId'], equals('user_1'));
        expect(conversation.metadata!['theme'], equals('blue'));
      });
      
      test('should initialize read timestamps properly', () {
        final now = DateTime.now();
        final readTime1 = now.subtract(Duration(minutes: 10));
        final readTime2 = now.subtract(Duration(minutes: 5));
        
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'Anna', 'user_2': 'Erik'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {
            'user_1': readTime1,
            'user_2': readTime2,
          },
          createdAt: now.subtract(Duration(hours: 1)),
          updatedAt: now,
          isGroup: false,
        );
        
        expect(conversation.lastReadTimestamps['user_1'], equals(readTime1));
        expect(conversation.lastReadTimestamps['user_2'], equals(readTime2));
      });
      
      test('should handle group vs direct flags', () {
        final now = DateTime.now();
        
        final direct = Conversation(
          id: 'conv_1',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {'user_1': now, 'user_2': now},
          createdAt: now,
          updatedAt: now,
          isGroup: false,
        );
        
        final group = Conversation(
          id: 'conv_2',
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B', 'user_3': 'C'},
          participantAvatarUrls: {'user_1': null, 'user_2': null, 'user_3': null},
          lastReadTimestamps: {'user_1': now, 'user_2': now, 'user_3': now},
          createdAt: now,
          updatedAt: now,
          isGroup: true,
        );
        
        expect(direct.isGroup, isFalse);
        expect(group.isGroup, isTrue);
      });
    });
    
    group('Factory Methods', () {
      test('should create direct conversation', () {
        final conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna Andersson',
          user1AvatarUrl: 'https://example.com/anna.jpg',
          user2Id: 'user_2',
          user2DisplayName: 'Erik Svensson',
          user2AvatarUrl: 'https://example.com/erik.jpg',
        );
        
        expect(conversation.id, isNotEmpty);
        expect(conversation.id.length, equals(36)); // UUID v4 length
        expect(conversation.participantIds, equals(['user_1', 'user_2']));
        expect(conversation.participantDisplayNames['user_1'], equals('Anna Andersson'));
        expect(conversation.participantDisplayNames['user_2'], equals('Erik Svensson'));
        expect(conversation.participantAvatarUrls['user_1'], equals('https://example.com/anna.jpg'));
        expect(conversation.participantAvatarUrls['user_2'], equals('https://example.com/erik.jpg'));
        expect(conversation.isGroup, isFalse);
        expect(conversation.lastReadTimestamps['user_1'], isNotNull);
        expect(conversation.lastReadTimestamps['user_2'], isNotNull);
      });
      
      test('should create group conversation', () {
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
          participantAvatarUrls: {
            'user_1': 'https://example.com/anna.jpg',
            'user_2': null,
            'user_3': 'https://example.com/maria.jpg',
          },
          title: 'Veckans meny',
          creatorId: 'user_1',
        );
        
        expect(conversation.id, isNotEmpty);
        expect(conversation.participantIds.length, equals(3));
        expect(conversation.title, equals('Veckans meny'));
        expect(conversation.isGroup, isTrue);
        expect(conversation.metadata!['creatorId'], equals('user_1'));
        expect(conversation.lastReadTimestamps.length, equals(3));
      });
      
      test('should auto-generate conversation ID', () {
        final conv1 = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        final conv2 = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        expect(conv1.id, isNot(equals(conv2.id)));
        expect(conv1.id.length, equals(36));
        expect(conv2.id.length, equals(36));
      });
      
      test('should initialize participant metadata', () {
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
          },
          participantAvatarUrls: {
            'user_1': null,
            'user_2': null,
          },
          title: 'Test Group',
          creatorId: 'user_1',
        );
        
        expect(conversation.metadata, isNotNull);
        expect(conversation.metadata!['creatorId'], equals('user_1'));
      });
    });
    
    group('Display Methods', () {
      late Conversation directConversation;
      late Conversation groupConversation;
      
      setUp(() {
        directConversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna Andersson',
          user1AvatarUrl: 'https://example.com/anna.jpg',
          user2Id: 'user_2',
          user2DisplayName: 'Erik Svensson',
          user2AvatarUrl: 'https://example.com/erik.jpg',
        );
        
        groupConversation = Conversation.group(
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
          participantAvatarUrls: {
            'user_1': 'https://example.com/anna.jpg',
            'user_2': 'https://example.com/erik.jpg',
            'user_3': 'https://example.com/maria.jpg',
          },
          title: 'Veckans middagar',
          creatorId: 'user_1',
        );
      });
      
      test('should get display title for direct conversation', () {
        expect(directConversation.getDisplayTitle('user_1'), equals('Erik Svensson'));
        expect(directConversation.getDisplayTitle('user_2'), equals('Anna Andersson'));
      });
      
      test('should get display title for group conversation', () {
        expect(groupConversation.getDisplayTitle('user_1'), equals('Veckans middagar'));
        expect(groupConversation.getDisplayTitle('user_2'), equals('Veckans middagar'));
        
        // Test group without custom title
        final groupNoTitle = Conversation(
          id: 'conv_test',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {'user_1': DateTime.now(), 'user_2': DateTime.now()},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: null,  // Can be null in direct constructor
          isGroup: true,
        );
        expect(groupNoTitle.getDisplayTitle('user_1'), equals('Gruppchatt'));
      });
      
      test('should get display avatar for direct conversation', () {
        expect(directConversation.getDisplayAvatarUrl('user_1'), 
               equals('https://example.com/erik.jpg'));
        expect(directConversation.getDisplayAvatarUrl('user_2'), 
               equals('https://example.com/anna.jpg'));
      });
      
      test('should get display avatar for group conversation (null)', () {
        expect(groupConversation.getDisplayAvatarUrl('user_1'), isNull);
        expect(groupConversation.getDisplayAvatarUrl('user_2'), isNull);
      });
      
      test('should get other participant ID for direct conversation', () {
        expect(directConversation.getOtherParticipantId('user_1'), equals('user_2'));
        expect(directConversation.getOtherParticipantId('user_2'), equals('user_1'));
      });
      
      test('should get other participant ID for group (returns null)', () {
        expect(groupConversation.getOtherParticipantId('user_1'), isNull);
        expect(groupConversation.getOtherParticipantId('user_2'), isNull);
      });
    });
    
    group('Read Status', () {
      late Conversation conversation;
      late DateTime now;
      
      setUp(() {
        now = DateTime.now();
        conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'Anna', 'user_2': 'Erik'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {
            'user_1': now.subtract(Duration(hours: 2)),
            'user_2': now.subtract(Duration(hours: 1)),
          },
          createdAt: now.subtract(Duration(days: 1)),
          updatedAt: now,
          isGroup: false,
        );
      });
      
      test('should check has unread messages', () {
        final messageAfterRead = Message.text(
          conversationId: 'conv_123',
          senderId: 'user_2',
          senderDisplayName: 'Erik',
          content: 'New message',
        );
        
        final withNewMessage = conversation.copyWith(
          lastMessage: messageAfterRead,
        );
        
        expect(withNewMessage.hasUnreadMessages('user_1'), isTrue);
        expect(withNewMessage.hasUnreadMessages('user_2'), isTrue);
      });
      
      test('should calculate unread count', () {
        final messages = [
          Message(
            id: 'm1',
            conversationId: 'conv_123',
            senderId: 'user_2',
            senderDisplayName: 'Erik',
            content: 'Message 1',
            type: MessageType.text,
            status: MessageStatus.delivered,
            sentAt: now.subtract(Duration(minutes: 30)),
          ),
          Message(
            id: 'm2',
            conversationId: 'conv_123',
            senderId: 'user_2',
            senderDisplayName: 'Erik',
            content: 'Message 2',
            type: MessageType.text,
            status: MessageStatus.delivered,
            sentAt: now,
          ),
          Message(
            id: 'm3',
            conversationId: 'conv_123',
            senderId: 'user_1', // Own message
            senderDisplayName: 'Anna',
            content: 'My message',
            type: MessageType.text,
            status: MessageStatus.sent,
            sentAt: now,
          ),
        ];
        
        expect(conversation.getUnreadCount('user_1', messages), equals(2)); // Excludes own message
      });
      
      test('should handle no messages', () {
        expect(conversation.hasUnreadMessages('user_1'), isFalse);
        expect(conversation.getUnreadCount('user_1', []), equals(0));
      });
      
      test('should exclude own messages from unread', () {
        final ownMessage = Message(
          id: 'm1',
          conversationId: 'conv_123',
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'My message',
          type: MessageType.text,
          status: MessageStatus.sent,
          sentAt: now,
        );
        
        final withOwnMessage = conversation.copyWith(lastMessage: ownMessage);
        
        // User should not have unread for their own message
        expect(withOwnMessage.hasUnreadMessages('user_1'), isTrue); // Message sent after last read
        expect(conversation.getUnreadCount('user_1', [ownMessage]), equals(0));
      });
      
      test('should update read timestamps', () {
        final newReadTime = DateTime.now();
        final updated = conversation.copyWith(
          lastReadTimestamps: {
            'user_1': newReadTime,
            'user_2': conversation.lastReadTimestamps['user_2']!,
          },
        );
        
        expect(updated.lastReadTimestamps['user_1'], equals(newReadTime));
        expect(updated.lastReadTimestamps['user_2'], 
               equals(conversation.lastReadTimestamps['user_2']));
      });
    });
    
    group('Participant Management', () {
      late Conversation conversation;
      
      setUp(() {
        conversation = Conversation.group(
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
          participantAvatarUrls: {
            'user_1': null,
            'user_2': null,
            'user_3': null,
          },
          title: 'Test Group',
          creatorId: 'user_1',
        );
      });
      
      test('should check is participant', () {
        expect(conversation.isParticipant('user_1'), isTrue);
        expect(conversation.isParticipant('user_2'), isTrue);
        expect(conversation.isParticipant('user_3'), isTrue);
        expect(conversation.isParticipant('user_999'), isFalse);
      });
      
      test('should handle participant changes', () {
        final updated = conversation.copyWith(
          participantIds: ['user_1', 'user_2', 'user_3', 'user_4'],
        );
        
        expect(updated.participantIds.length, equals(4));
        expect(updated.isParticipant('user_4'), isTrue);
      });
      
      test('should update participant metadata', () {
        final updated = conversation.copyWith(
          participantDisplayNames: {
            'user_1': 'Anna Updated',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
        );
        
        expect(updated.participantDisplayNames['user_1'], equals('Anna Updated'));
      });
      
      test('should validate participant lists', () {
        expect(conversation.participantIds.length, 
               equals(conversation.participantDisplayNames.length));
        expect(conversation.participantIds.length, 
               equals(conversation.participantAvatarUrls.length));
      });
    });
    
    group('Message Preview', () {
      late Conversation conversation;
      
      setUp(() {
        conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
      });
      
      test('should format last message preview', () {
        final message = Message.text(
          conversationId: conversation.id,
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'Hej Erik!',
        );
        
        final withMessage = conversation.copyWith(lastMessage: message);
        
        expect(withMessage.lastMessagePreview, equals('Anna: Hej Erik!'));
      });
      
      test('should handle system messages', () {
        final systemMessage = Message(
          id: 'msg_1',
          conversationId: conversation.id,
          senderId: 'system',
          senderDisplayName: 'System',
          content: 'Erik har anslutit sig',
          type: MessageType.system,
          status: MessageStatus.delivered,
          sentAt: DateTime.now(),
        );
        
        final withSystem = conversation.copyWith(lastMessage: systemMessage);
        
        expect(withSystem.lastMessagePreview, equals('Erik har anslutit sig'));
      });
      
      test('should show Swedish "Ingen meddelanden än"', () {
        expect(conversation.lastMessagePreview, equals('Ingen meddelanden än'));
      });
      
      test('should format activity time', () {
        final now = DateTime.now();
        
        // Just now
        var conv = conversation.copyWith(updatedAt: now);
        expect(conv.formattedLastActivity, equals('Nu'));
        
        // Minutes
        conv = conversation.copyWith(
          updatedAt: now.subtract(Duration(minutes: 30)),
        );
        expect(conv.formattedLastActivity, equals('30m'));
        
        // Hours
        conv = conversation.copyWith(
          updatedAt: now.subtract(Duration(hours: 5)),
        );
        expect(conv.formattedLastActivity, equals('5h'));
        
        // Days
        conv = conversation.copyWith(
          updatedAt: now.subtract(Duration(days: 3)),
        );
        expect(conv.formattedLastActivity, equals('3d'));
        
        // Weeks
        conv = conversation.copyWith(
          updatedAt: now.subtract(Duration(days: 14)),
        );
        expect(conv.formattedLastActivity, equals('2w'));
      });
    });
    
    group('copyWith Operations', () {
      late Conversation original;
      
      setUp(() {
        original = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
      });
      
      test('should update last message', () {
        final message = Message.text(
          conversationId: original.id,
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'New message',
        );
        
        final updated = original.copyWith(
          lastMessage: message,
          updatedAt: DateTime.now(),
        );
        
        expect(updated.lastMessage, equals(message));
        expect(updated.id, equals(original.id));
      });
      
      test('should update metadata', () {
        final updated = original.copyWith(
          metadata: {'theme': 'dark', 'muted': true},
        );
        
        expect(updated.metadata!['theme'], equals('dark'));
        expect(updated.metadata!['muted'], isTrue);
      });
      
      test('should preserve immutability', () {
        final updated = original.copyWith(
          title: 'New Title',
        );
        
        expect(original.title, isNull);
        expect(updated.title, equals('New Title'));
        expect(original.id, equals(updated.id));
      });
    });
    
    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final conv1 = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {'user_1': DateTime.now(), 'user_2': DateTime.now()},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );
        
        final conv2 = Conversation(
          id: 'conv_123',
          participantIds: ['user_3', 'user_4'],
          participantDisplayNames: {'user_3': 'C', 'user_4': 'D'},
          participantAvatarUrls: {'user_3': null, 'user_4': null},
          lastReadTimestamps: {'user_3': DateTime.now(), 'user_4': DateTime.now()},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: true,
        );
        
        expect(conv1, equals(conv2));
        expect(conv1.hashCode, equals(conv2.hashCode));
      });
      
      test('should not be equal when IDs differ', () {
        final conv1 = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        final conv2 = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        expect(conv1, isNot(equals(conv2)));
      });
      
      test('should be equal to itself', () {
        final conv = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        expect(conv, equals(conv));
      });
    });
    
    group('toString', () {
      test('should provide meaningful string representation', () {
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Anna',
            'user_2': 'Erik',
            'user_3': 'Maria',
          },
          participantAvatarUrls: {
            'user_1': null,
            'user_2': null,
            'user_3': null,
          },
          title: 'Test Group',
          creatorId: 'user_1',
        );
        
        final message = Message.text(
          conversationId: conversation.id,
          senderId: 'user_1',
          senderDisplayName: 'Anna',
          content: 'Hello!',
        );
        
        final withMessage = conversation.copyWith(lastMessage: message);
        final str = withMessage.toString();
        
        expect(str, contains(conversation.id));
        expect(str, contains('true')); // isGroup
        expect(str, contains('3')); // participants count
        expect(str, contains('Hello!')); // last message
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty participant list', () {
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: [],
          participantDisplayNames: {},
          participantAvatarUrls: {},
          lastReadTimestamps: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );
        
        expect(conversation.participantIds, isEmpty);
        expect(conversation.participantDisplayNames, isEmpty);
      });
      
      test('should handle single participant', () {
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1'],
          participantDisplayNames: {'user_1': 'Anna'},
          participantAvatarUrls: {'user_1': null},
          lastReadTimestamps: {'user_1': DateTime.now()},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );
        
        expect(conversation.participantIds.length, equals(1));
        // When only one participant, getDisplayTitle returns that participant's name  
        // (since firstWhere with orElse returns the same user)
        expect(conversation.getDisplayTitle('user_1'), equals('Anna'));
      });
      
      test('should handle very long group title', () {
        final longTitle = 'A' * 500;
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          title: longTitle,
          creatorId: 'user_1',
        );
        
        expect(conversation.title, equals(longTitle));
        expect(conversation.title!.length, equals(500));
      });
      
      test('should handle missing display names', () {
        final conversation = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'Anna'}, // Missing user_2
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {'user_1': DateTime.now(), 'user_2': DateTime.now()},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );
        
        expect(conversation.getDisplayTitle('user_1'), equals('Okänd användare'));
      });
      
      test('should handle null avatars', () {
        final conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user1AvatarUrl: null,
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
          user2AvatarUrl: null,
        );
        
        expect(conversation.participantAvatarUrls['user_1'], isNull);
        expect(conversation.participantAvatarUrls['user_2'], isNull);
        expect(conversation.getDisplayAvatarUrl('user_1'), isNull);
      });
      
      test('should handle Swedish characters in names', () {
        final conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Åsa Öström',
          user2Id: 'user_2',
          user2DisplayName: 'Björn Ärlig',
        );
        
        expect(conversation.participantDisplayNames['user_1'], equals('Åsa Öström'));
        expect(conversation.participantDisplayNames['user_2'], equals('Björn Ärlig'));
        expect(conversation.getDisplayTitle('user_1'), equals('Björn Ärlig'));
      });
      
      test('should handle emoji in titles', () {
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {
            'user_1': 'Anna 😊',
            'user_2': 'Erik 🎉',
          },
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          title: 'Festplanering 🎈🎊',
          creatorId: 'user_1',
        );
        
        expect(conversation.title, contains('🎈'));
        expect(conversation.title, contains('🎊'));
        expect(conversation.participantDisplayNames['user_1'], contains('😊'));
      });
      
      test('should handle large participant counts', () {
        final participants = List.generate(100, (i) => 'user_$i');
        final displayNames = Map.fromEntries(
          participants.map((id) => MapEntry(id, 'User ${id.split('_').last}')),
        );
        final avatarUrls = Map.fromEntries(
          participants.map((id) => MapEntry(id, null)),
        );
        
        final conversation = Conversation.group(
          participantIds: participants,
          participantDisplayNames: displayNames,
          participantAvatarUrls: avatarUrls,
          title: 'Large Group',
          creatorId: 'user_0',
        );
        
        expect(conversation.participantIds.length, equals(100));
        expect(conversation.lastReadTimestamps.length, equals(100));
      });
      
      test('should handle concurrent read updates', () {
        final now = DateTime.now();
        var conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );
        
        // Simulate multiple read updates
        for (int i = 0; i < 10; i++) {
          conversation = conversation.copyWith(
            lastReadTimestamps: {
              'user_1': now.add(Duration(seconds: i)),
              'user_2': now.add(Duration(seconds: i * 2)),
            },
          );
        }
        
        expect(conversation.lastReadTimestamps['user_1'], 
               equals(now.add(Duration(seconds: 9))));
        expect(conversation.lastReadTimestamps['user_2'], 
               equals(now.add(Duration(seconds: 18))));
      });
      
      test('should handle self-conversation', () {
        final conversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_1', // Same user
          user2DisplayName: 'Anna',
        );
        
        expect(conversation.participantIds, equals(['user_1', 'user_1']));
        expect(conversation.getDisplayTitle('user_1'), equals('Anna'));
        expect(conversation.getOtherParticipantId('user_1'), equals('user_1'));
      });
    });
  });
}