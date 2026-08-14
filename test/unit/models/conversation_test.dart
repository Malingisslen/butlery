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
        expect(
          conversation.participantDisplayNames['user_1'],
          equals('Anna Andersson'),
        );
        expect(
          conversation.participantDisplayNames['user_2'],
          equals('Erik Svensson'),
        );
        expect(
          conversation.participantAvatarUrls['user_1'],
          equals('https://example.com/anna.jpg'),
        );
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
          participantDisplayNames: {
            'user_1': 'A',
            'user_2': 'B',
            'user_3': 'C',
          },
          participantAvatarUrls: {
            'user_1': null,
            'user_2': null,
            'user_3': null,
          },
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
        expect(
          conversation.participantDisplayNames['user_1'],
          equals('Anna Andersson'),
        );
        expect(
          conversation.participantDisplayNames['user_2'],
          equals('Erik Svensson'),
        );
        expect(
          conversation.participantAvatarUrls['user_1'],
          equals('https://example.com/anna.jpg'),
        );
        expect(
          conversation.participantAvatarUrls['user_2'],
          equals('https://example.com/erik.jpg'),
        );
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
        expect(
          directConversation.getDisplayTitle('user_1'),
          equals('Erik Svensson'),
        );
        expect(
          directConversation.getDisplayTitle('user_2'),
          equals('Anna Andersson'),
        );
      });

      test('should get display title for group conversation', () {
        expect(
          groupConversation.getDisplayTitle('user_1'),
          equals('Veckans middagar'),
        );
        expect(
          groupConversation.getDisplayTitle('user_2'),
          equals('Veckans middagar'),
        );

        // Test group without custom title
        final groupNoTitle = Conversation(
          id: 'conv_test',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {
            'user_1': DateTime.now(),
            'user_2': DateTime.now(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: null, // Can be null in direct constructor
          isGroup: true,
        );
        expect(groupNoTitle.getDisplayTitle('user_1'), equals('Gruppchatt'));
      });

      test('should get display avatar for direct conversation', () {
        expect(
          directConversation.getDisplayAvatarUrl('user_1'),
          equals('https://example.com/erik.jpg'),
        );
        expect(
          directConversation.getDisplayAvatarUrl('user_2'),
          equals('https://example.com/anna.jpg'),
        );
      });

      test('should get display avatar for group conversation (null)', () {
        expect(groupConversation.getDisplayAvatarUrl('user_1'), isNull);
        expect(groupConversation.getDisplayAvatarUrl('user_2'), isNull);
      });

      test('should get other participant ID for direct conversation', () {
        expect(
          directConversation.getOtherParticipantId('user_1'),
          equals('user_2'),
        );
        expect(
          directConversation.getOtherParticipantId('user_2'),
          equals('user_1'),
        );
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

        expect(
          conversation.getUnreadCount('user_1', messages),
          equals(2),
        ); // Excludes own message
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
        expect(
          withOwnMessage.hasUnreadMessages('user_1'),
          isTrue,
        ); // Message sent after last read
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
        expect(
          updated.lastReadTimestamps['user_2'],
          equals(conversation.lastReadTimestamps['user_2']),
        );
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

        expect(
          updated.participantDisplayNames['user_1'],
          equals('Anna Updated'),
        );
      });

      test('should validate participant lists', () {
        expect(
          conversation.participantIds.length,
          equals(conversation.participantDisplayNames.length),
        );
        expect(
          conversation.participantIds.length,
          equals(conversation.participantAvatarUrls.length),
        );
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

      // BUT-1838: `Conversation.lastMessagePreview` is DELETED, and these three
      // tests went with it. It built the same preview as the conversation list
      // but without the history cut-off, so it would have shown a member a
      // message `firestore.rules` refuses them. It had no production caller —
      // only these tests — which is why deleting beat guarding: an unguarded
      // twin of a privacy check is what the next caller reaches for.
      //
      // All three cases are now pinned where the preview is actually built, in
      // `test/widget/messaging/conversation_list_item_history_preview_test.dart`
      // ("previews a message sent after the reader joined", "previews a
      // readable SYSTEM row verbatim", and the two no-message tests), together
      // with the cut-off none of them knew about.
      //
      // Not a like-for-like move, in two places, and that is deliberate:
      //   - the model prefixed the sender on EVERY conversation ("Anna: Hej
      //     Erik!"), including a direct chat. The list only prefixes in a
      //     group; a 1:1 row shows the bare content, and that is what the
      //     widget suite pins.
      //   - the model's empty state was "Inga meddelanden än". The list says
      //     "Grupp skapad" for a group and "Säg hej." for a direct chat, and
      //     keeps "Inga meddelanden än" for the third state the model had no
      //     concept of: a last message this member may not read.

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

        // BUT-1047: ContextualTimeFormatter.compact promotes past 7d to
        // DateFormat.MMMd (e.g. "Apr 22" / "22 apr"). Assert promotion
        // happened (not the legacy "14d") + contains a month-name letter
        // run.
        conv = conversation.copyWith(
          updatedAt: now.subtract(Duration(days: 14)),
        );
        expect(conv.formattedLastActivity, isNot(equals('14d')));
        expect(conv.formattedLastActivity, matches(RegExp(r'[A-Za-z]{3}')));
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

    // BUT-1838. `groupId` and `memberSince` are server-owned, so copyWith has
    // no PARAMETER for them — they are carried unconditionally. That makes
    // them the exact shape that goes missing in a field-by-field rebuild, and
    // the consequence is not cosmetic: with `groupId` dropped,
    // `historyQueryStartFor` answers null, the client's message query loses its
    // `sentAt >=` filter, and `firestore.rules` then refuses the WHOLE query
    // rather than trimming it — the group chat stops loading entirely.
    group('copyWith carries the server-owned group fields', () {
      final joinedAt = DateTime.utc(2026, 3, 4, 5, 6);
      final founderJoinedAt = DateTime.utc(2026, 1, 1);

      Conversation groupConversation() => Conversation(
        id: 'conv_group',
        participantIds: const ['user_1', 'user_2'],
        participantDisplayNames: const {'user_1': 'Anna', 'user_2': 'Erik'},
        participantAvatarUrls: const {'user_1': null, 'user_2': null},
        lastReadTimestamps: const {},
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        isGroup: true,
        title: 'Middagsgänget',
        groupId: 'chat-group-1',
        memberSince: {'user_1': founderJoinedAt, 'user_2': joinedAt},
      );

      test('survive a pin toggle — the live ConversationsViewModel path', () {
        // `ConversationsViewModel.togglePin` rebuilds the conversation with
        // exactly this call, optimistically, on every pin tap.
        final original = groupConversation();

        final pinned = original.copyWith(
          isPinned: true,
          pinnedAt: DateTime.utc(2026, 5, 5),
        );

        expect(pinned.groupId, equals('chat-group-1'));
        expect(pinned.memberSince, equals(original.memberSince));
        expect(pinned.historyQueryStartFor('user_2'), equals(joinedAt));
        expect(pinned.isPinned, isTrue); // positive control: the copy happened
      });

      // BUT-1838: `createChatGroup` stamps `memberSince` for EVERY founding
      // member, including the creator — so a bare `memberSince[uid]` lookup is
      // non-null for the whole founding roster and would put "Du gick med här"
      // at the top of every group chat, above "gruppen skapades". A founder's
      // stamp is the same value the conversation's `createdAt` carries, which
      // is what separates the two.
      // The two methods answer DIFFERENT questions, and pinning both here is
      // the point: the QUERY must mirror the rule for everybody (the rule
      // filters founders too, and a reader that does not can be handed a
      // document the rules refuse, which fails the whole query), while the
      // DIVIDER must fire only for someone who joined later.
      test(
        'the query filters a founder; the divider does not show for one',
        () {
          final conversation = groupConversation();

          expect(
            conversation.historyQueryStartFor('user_1'),
            equals(founderJoinedAt),
            reason: 'the query mirrors the rule, which stamps founders too',
          );
          expect(
            conversation.joinedLaterAt('user_1'),
            isNull,
            reason: 'no "du gick med här" above "gruppen skapades"',
          );

          expect(
            conversation.historyQueryStartFor('user_2'),
            equals(joinedAt),
            reason: 'a later joiner keeps their cut-off — the control',
          );
          expect(
            conversation.joinedLaterAt('user_2'),
            equals(joinedAt),
            reason: 'and gets the divider',
          );
        },
      );

      test('survive an archive toggle and a lastMessage update', () {
        final original = groupConversation();

        final archived = original.copyWith(
          isArchived: true,
          archivedAt: DateTime.utc(2026, 5, 6),
        );
        final withMessage = archived.copyWith(
          lastMessage: Message.text(
            conversationId: 'conv_group',
            senderId: 'user_1',
            senderDisplayName: 'Anna',
            content: 'Hej',
          ),
          updatedAt: DateTime.utc(2026, 5, 7),
        );

        // Two hops, because a single copyWith is where a dropped field is
        // easiest to spot and a chained rebuild is where it actually happens.
        expect(withMessage.groupId, equals('chat-group-1'));
        expect(withMessage.historyQueryStartFor('user_2'), equals(joinedAt));
        expect(withMessage.isArchived, isTrue);
        expect(withMessage.lastMessage, isNotNull);
      });

      test('a direct conversation stays direct through copyWith', () {
        // The negative half: copyWith must not INVENT a groupId either, or a
        // direct chat would start filtering its own history away.
        final direct = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Anna',
          user2Id: 'user_2',
          user2DisplayName: 'Erik',
        );

        final updated = direct.copyWith(isMuted: true);

        expect(updated.groupId, isNull);
        expect(updated.memberSince, isEmpty);
        expect(updated.historyQueryStartFor('user_1'), isNull);
        expect(updated.isMuted, isTrue);
      });
    });

    group('historyQueryStartFor', () {
      final joinedAt = DateTime.utc(2026, 3, 4, 5, 6);

      Conversation build({
        String? groupId,
        Map<String, DateTime> memberSince = const {},
        bool isGroup = true,
      }) => Conversation(
        id: 'conv_history',
        participantIds: const ['user_1', 'user_2'],
        participantDisplayNames: const {},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        isGroup: isGroup,
        groupId: groupId,
        memberSince: memberSince,
      );

      test('returns the joining member\'s own stamp', () {
        final conversation = build(
          groupId: 'chat-group-1',
          memberSince: {'user_2': joinedAt},
        );

        expect(conversation.historyQueryStartFor('user_2'), equals(joinedAt));
      });

      test('returns null for a founding member with no stamp', () {
        final conversation = build(
          groupId: 'chat-group-1',
          memberSince: {'user_2': joinedAt},
        );

        // user_1 was there from the start — no cut-off, so no filter and no
        // "Du gick med här" divider.
        expect(conversation.historyQueryStartFor('user_1'), isNull);
      });

      test(
        'returns null when groupId is absent even though isGroup is true '
        'and a stamp exists',
        () {
          // The discriminating case for the `groupId == null ?` guard. The
          // model doc is explicit that `isGroup` must NOT be substituted for
          // `groupId`: `isGroup` is an ordinary client field, and the rule in
          // firestore.rules keys on the presence of `groupId`. A conversation
          // predating BUT-1838 has isGroup true and no groupId, and filtering
          // its history would hide messages the rules would happily serve.
          final legacy = build(
            groupId: null,
            memberSince: {'user_2': joinedAt},
            isGroup: true,
          );

          expect(legacy.isGroup, isTrue, reason: 'premise');
          expect(
            legacy.memberSince['user_2'],
            equals(joinedAt),
            reason:
                'premise: the stamp is present and would be returned '
                'if the groupId guard were dropped',
          );
          expect(legacy.historyQueryStartFor('user_2'), isNull);
        },
      );
    });

    // BUT-1838 review follow-up. `canReadMessageAt` is the ONE spelling of the
    // comparison the list row, the search filter and the message query used to
    // hand-roll separately — and unlike `historyQueryStartFor`, whose null means
    // "no cut-off", it fails CLOSED in the two states where the rules deny:
    // an unknown reader and a `groupId` conversation with no stamp for them.
    group('canReadMessageAt', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final joinedAt = DateTime.utc(2026, 3, 4, 5, 6);
      final beforeJoin = DateTime.utc(2026, 2, 1);
      final afterJoin = DateTime.utc(2026, 4, 1);

      Conversation build({
        String? groupId = 'chat-group-1',
        Map<String, DateTime> memberSince = const {},
        bool isGroup = true,
      }) => Conversation(
        id: 'conv_can_read',
        participantIds: const ['user_1', 'user_2'],
        participantDisplayNames: const {},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        createdAt: createdAt,
        updatedAt: createdAt,
        isGroup: isGroup,
        groupId: groupId,
        memberSince: memberSince,
      );

      test('allows anything in a direct conversation', () {
        // No groupId, so no cut-off exists — even with a stamp lying around,
        // which is the shape that would blank a direct chat if the guard read
        // `memberSince` before checking `groupId`.
        final direct = build(
          groupId: null,
          isGroup: false,
          memberSince: {'user_2': joinedAt},
        );

        expect(direct.canReadMessageAt(beforeJoin, 'user_2'), isTrue);
      });

      test(
        'allows a LEGACY group — isGroup true, no groupId — even with a stamp '
        'later than the message',
        () {
          // The only fixture that REACHES `canReadMessageAt` and separates
          // `groupId == null` from `!isGroup`. Every other one reaching it has
          // both flags or neither, so on them the two predicates agree and the
          // substitution survives. (The `historyQueryStartFor` group above
          // builds this same shape, but never calls this method.) A
          // conversation created before BUT-1838 has `isGroup` true and no
          // `groupId`; `firestore.rules` keys on `groupId`, so it serves that
          // whole history, and a guard keyed on `isGroup` would blank a chat
          // the rules happily read.
          final legacy = build(
            groupId: null,
            isGroup: true,
            memberSince: {'user_2': joinedAt},
          );

          expect(legacy.isGroup, isTrue, reason: 'premise');
          expect(
            legacy.memberSince['user_2'],
            equals(joinedAt),
            reason:
                'premise: the stamp is present and later than the message, so '
                'a guard keyed on isGroup would refuse this',
          );
          expect(legacy.canReadMessageAt(beforeJoin, 'user_2'), isTrue);
        },
      );

      test('refuses a message sent before the reader joined', () {
        final conversation = build(memberSince: {'user_2': joinedAt});

        expect(conversation.canReadMessageAt(beforeJoin, 'user_2'), isFalse);
      });

      test('allows a message sent after the reader joined', () {
        final conversation = build(memberSince: {'user_2': joinedAt});

        expect(conversation.canReadMessageAt(afterJoin, 'user_2'), isTrue);
      });

      test('allows a message sent EXACTLY at the stamp — the rule is >=', () {
        // `isBefore` and `!isAfter` disagree only here, and firestore.rules
        // spells it `sentAt >= memberSince[uid]`.
        final conversation = build(memberSince: {'user_2': joinedAt});

        expect(conversation.canReadMessageAt(joinedAt, 'user_2'), isTrue);
      });

      test('refuses an EMPTY reader id even when the message is readable', () {
        // Every caller passes `currentUserId.orEmpty()`, so '' is reachable
        // while the signed-in user is momentarily unknown. `memberSince['']`
        // is null, which a naive guard reads as "no cut-off, show it"; the
        // rule's `.get(uid, request.time)` default denies.
        final conversation = build(memberSince: {'user_2': joinedAt});

        expect(
          conversation.canReadMessageAt(afterJoin, 'user_2'),
          isTrue,
          reason: 'premise: this message is readable for a real member',
        );
        expect(conversation.canReadMessageAt(afterJoin, ''), isFalse);
      });

      test('refuses a group reader carrying no stamp of their own', () {
        // Reachable: `stageMemberRemoval` deletes `memberSince.{uid}` and
        // leaves `groupId` in place, so a removed member sits in exactly this
        // state. Someone else's stamp is present, so a pass here could not be
        // blamed on an empty map.
        final conversation = build(memberSince: {'user_1': createdAt});

        expect(
          conversation.historyQueryStartFor('user_2'),
          isNull,
          reason: 'premise: the sibling method reports no cut-off here',
        );
        expect(conversation.canReadMessageAt(afterJoin, 'user_2'), isFalse);
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final conv1 = Conversation(
          id: 'conv_123',
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'A', 'user_2': 'B'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          lastReadTimestamps: {
            'user_1': DateTime.now(),
            'user_2': DateTime.now(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );

        final conv2 = Conversation(
          id: 'conv_123',
          participantIds: ['user_3', 'user_4'],
          participantDisplayNames: {'user_3': 'C', 'user_4': 'D'},
          participantAvatarUrls: {'user_3': null, 'user_4': null},
          lastReadTimestamps: {
            'user_3': DateTime.now(),
            'user_4': DateTime.now(),
          },
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
          lastReadTimestamps: {
            'user_1': DateTime.now(),
            'user_2': DateTime.now(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: false,
        );

        expect(conversation.getDisplayTitle('user_1'), equals('?'));
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

        expect(
          conversation.participantDisplayNames['user_1'],
          equals('Åsa Öström'),
        );
        expect(
          conversation.participantDisplayNames['user_2'],
          equals('Björn Ärlig'),
        );
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

        expect(
          conversation.lastReadTimestamps['user_1'],
          equals(now.add(Duration(seconds: 9))),
        );
        expect(
          conversation.lastReadTimestamps['user_2'],
          equals(now.add(Duration(seconds: 18))),
        );
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
