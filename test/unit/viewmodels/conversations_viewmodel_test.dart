import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';

import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/services/permission_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';

// NOTE: After AsyncOperationMixin migration:
// - isLoading → isLoading
// - error → error

// Test data builders
class ConversationBuilder {
  static Conversation build({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Map<String, String?>? participantAvatarUrls,
    Message? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    bool isGroup = false,
    Map<String, DateTime>? lastReadTimestamps,
    Map<String, dynamic>? metadata,
    String? groupId,
    Map<String, DateTime>? memberSince,
  }) {
    final defaultId = id ?? 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final defaultParticipantIds = participantIds ?? ['user1', 'user2'];
    final now = DateTime.now();

    return Conversation(
      id: defaultId,
      participantIds: defaultParticipantIds,
      participantDisplayNames:
          participantDisplayNames ??
          {
            'user1': 'Anna Andersson',
            'user2': 'Erik Svensson',
          },
      participantAvatarUrls: participantAvatarUrls ?? {},
      lastMessage: lastMessage,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      title: title,
      isGroup: isGroup,
      lastReadTimestamps: lastReadTimestamps ?? {},
      metadata: metadata ?? {},
      groupId: groupId,
      memberSince: memberSince ?? const {},
    );
  }

  static Conversation buildDirect({
    String? id,
    String? user1Id,
    String? user2Id,
    String? user1Name,
    String? user2Name,
    Message? lastMessage,
  }) {
    final userId1 = user1Id ?? 'user1';
    final userId2 = user2Id ?? 'user2';

    return build(
      id: id,
      participantIds: [userId1, userId2],
      participantDisplayNames: {
        userId1: user1Name ?? 'Anna Andersson',
        userId2: user2Name ?? 'Erik Svensson',
      },
      lastMessage: lastMessage,
      isGroup: false,
    );
  }

  static Conversation buildGroup({
    String? id,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Message? lastMessage,
    String? groupId,
  }) {
    final ids = participantIds ?? ['user1', 'user2', 'user3'];
    final names =
        participantDisplayNames ??
        {
          'user1': 'Anna Andersson',
          'user2': 'Erik Svensson',
          'user3': 'Maria Johansson',
        };

    return build(
      id: id,
      title: title ?? 'Matgruppen',
      participantIds: ids,
      participantDisplayNames: names,
      lastMessage: lastMessage,
      isGroup: true,
      groupId: groupId,
    );
  }
}

class MessageBuilder {
  static Message build({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderDisplayName,
    String? content,
    MessageType type = MessageType.text,
    MessageStatus status = MessageStatus.delivered,
    DateTime? sentAt,
    Map<String, dynamic>? data,
  }) {
    final now = DateTime.now();

    return Message(
      id: id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId ?? 'conv_test',
      senderId: senderId ?? 'user1',
      senderDisplayName: senderDisplayName ?? 'Test User',
      type: type,
      content: content ?? 'Test message',
      status: status,
      sentAt: sentAt ?? now,
      metadata: data ?? {},
    );
  }
}

void main() {
  group('ConversationsViewModel', () {
    late ConversationsViewModel viewModel;
    late MockMessagingService mockMessagingService;
    late MockChatGroupRepository mockChatGroupRepository;
    late FakeAuthRepository mockAuthRepository;
    late StreamController<List<Conversation>> conversationsStreamController;
    const testUserId = 'test-user-123';

    // Test conversations
    final testDirectConversation = ConversationBuilder.buildDirect(
      id: 'conv_direct_1',
      user1Id: testUserId,
      user2Id: 'other_user',
      user1Name: 'Test User',
      user2Name: 'Anna Andersson',
      lastMessage: MessageBuilder.build(
        content: 'Hej! Hur mår du?',
        senderId: 'other_user',
        senderDisplayName: 'Anna Andersson',
      ),
    );

    final testGroupConversation = ConversationBuilder.buildGroup(
      id: 'conv_group_1',
      title: 'Köttbullsälskare',
      participantIds: [testUserId, 'user2', 'user3'],
      participantDisplayNames: {
        testUserId: 'Test User',
        'user2': 'Erik Svensson',
        'user3': 'Maria Öberg',
      },
      lastMessage: MessageBuilder.build(
        content: 'Någon som vill laga köttbullar imorgon?',
        senderId: 'user2',
        senderDisplayName: 'Erik Svensson',
      ),
    );

    final testSearchConversation = ConversationBuilder.buildDirect(
      id: 'conv_search_1',
      user1Id: testUserId,
      user2Id: 'search_user',
      user1Name: 'Test User',
      user2Name: 'Åsa Ängström',
      lastMessage: MessageBuilder.build(
        content: 'Recept för räksmörgås',
        senderId: 'search_user',
        senderDisplayName: 'Åsa Ängström',
      ),
    );

    // Dedicated fixture for the "Leave Group" tests below — leaveGroup now
    // reads groupId off the loaded conversation list rather than calling
    // MessagingService, so these tests must seed the stream first.
    Conversation leaveGroupConversation({
      String id = 'group_123',
      String groupId = 'chatgroup_123',
    }) => ConversationBuilder.buildGroup(
      id: id,
      title: 'Lämnabar grupp',
      participantIds: [testUserId, 'user2'],
      groupId: groupId,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ConversationBuilder.build());
      registerFallbackValue(MessageBuilder.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockMessagingService = MockMessagingService();
      mockChatGroupRepository = MockChatGroupRepository();
      mockAuthRepository = FakeAuthRepository();
      conversationsStreamController =
          StreamController<List<Conversation>>.broadcast();

      // Configure default mock behavior
      mockAuthRepository.setAuthState(
        userId: testUserId,
        isAuthenticated: true,
      );

      // Configure PermissionService in ServiceLocator (used by currentUserId getter)
      final mockPermissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      mockPermissionService.setPermissionState(
        currentUserId: testUserId,
        isAuthenticated: true,
      );

      when(
        () => mockMessagingService.getMyConversations(),
      ).thenAnswer((_) => conversationsStreamController.stream);

      when(
        () => mockMessagingService.markConversationAsRead(any()),
      ).thenAnswer((_) async => {});

      when(
        () => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        ),
      ).thenAnswer((_) async => 'new_conv_direct');

      when(
        () => mockMessagingService.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        ),
      ).thenAnswer((_) async => 'new_conv_group');

      when(
        () => mockChatGroupRepository.removeMember(
          groupId: any(named: 'groupId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      // Create viewModel
      viewModel = ConversationsViewModel(
        messagingService: mockMessagingService,
        chatGroupRepository: mockChatGroupRepository,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await conversationsStreamController.close();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with loading state', () {
        // Assert initial state - Stream loading
        expect(viewModel.isLoadingConversations, isTrue);
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.conversationsError, isNull);
        expect(viewModel.hasConversations, isFalse);
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.isSearching, isFalse);

        // Operation state (AsyncOperationMixin) should be idle
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should setup stream subscription on initialization', () {
        // Verify stream subscription was created
        verify(() => mockMessagingService.getMyConversations()).called(1);
      });

      test('should handle error during initialization', () {
        // Arrange
        when(
          () => mockMessagingService.getMyConversations(),
        ).thenThrow(Exception('Stream setup failed'));

        // Act
        final errorViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );

        // Assert
        expect(
          errorViewModel.conversationsError,
          equals('Kunde inte ladda konversationer'),
        );
        expect(errorViewModel.isLoadingConversations, isFalse);

        // Cleanup
        errorViewModel.dispose();
      });

      test('should load conversations from stream successfully', () async {
        // Arrange
        final conversations = [testDirectConversation, testGroupConversation];

        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero); // Allow stream to process

        // Assert
        expect(viewModel.conversations.length, equals(2));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasConversations, isTrue);
      });

      test('should get current user ID from auth repository', () {
        // Assert
        expect(viewModel.currentUserId, equals(testUserId));
      });
    });

    group('Conversation Updates', () {
      test('should receive and update conversations from stream', () async {
        // Arrange
        final conversations = [
          testDirectConversation,
          testGroupConversation,
          testSearchConversation,
        ];

        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero);

        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.conversations[0].id, equals('conv_direct_1'));
        expect(viewModel.conversations[1].id, equals('conv_group_1'));
        expect(viewModel.conversations[2].id, equals('conv_search_1'));
      });

      test('should handle empty conversation list', () async {
        // Act
        conversationsStreamController.add([]);
        await Future.delayed(Duration.zero);

        // Assert
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.hasConversations, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should handle multiple conversation updates', () async {
        // Act - First update
        conversationsStreamController.add([testDirectConversation]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(1));

        // Act - Second update
        conversationsStreamController.add([
          testDirectConversation,
          testGroupConversation,
        ]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(2));

        // Act - Third update
        conversationsStreamController.add([testGroupConversation]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(1));
      });

      test('should handle stream errors', () async {
        // Act
        conversationsStreamController.addError('Stream error');
        await Future.delayed(Duration.zero);

        // Assert - Stream error, check stream state
        expect(
          viewModel.conversationsError,
          equals('Kunde inte ladda konversationer'),
        );
        expect(viewModel.isLoadingConversations, isFalse);
      });

      test('should not update when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );

        // Load initial data
        conversationsStreamController.add([testDirectConversation]);
        await Future.delayed(Duration.zero);
        expect(testViewModel.conversations.length, equals(1));

        // Now dispose
        testViewModel.dispose();

        // Act - Try to update after dispose
        conversationsStreamController.add([
          testDirectConversation,
          testGroupConversation,
        ]);
        await Future.delayed(Duration.zero);

        // Assert - Should not crash, conversations should remain as before dispose
        // We can't access conversations after dispose as it violates ChangeNotifier contract
        // The test passes if it doesn't crash
      });

      test('should preserve conversation order from stream', () async {
        // Arrange
        final conversations = [
          testGroupConversation,
          testSearchConversation,
          testDirectConversation,
        ];

        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero);

        // Assert
        expect(viewModel.conversations[0].id, equals('conv_group_1'));
        expect(viewModel.conversations[1].id, equals('conv_search_1'));
        expect(viewModel.conversations[2].id, equals('conv_direct_1'));
      });
    });

    group('Search Functionality', () {
      setUp(() async {
        // Load test conversations
        conversationsStreamController.add([
          testDirectConversation,
          testGroupConversation,
          testSearchConversation,
        ]);
        await Future.delayed(Duration.zero);
      });

      test('should search by conversation title', () {
        // Act
        viewModel.updateSearchQuery('köttbull');

        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].title, equals('Köttbullsälskare'));
        expect(viewModel.searchQuery, equals('köttbull'));
      });

      test('should search by last message content', () {
        // Act
        viewModel.updateSearchQuery('räksmörgås');

        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].id, equals('conv_search_1'));
      });

      test('should perform case-insensitive search', () {
        // Act
        viewModel.updateSearchQuery('KÖTTBULL');

        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].title, equals('Köttbullsälskare'));
      });

      test('should clear search and show all conversations', () {
        // Arrange
        viewModel.updateSearchQuery('köttbull');
        expect(viewModel.conversations.length, equals(1));

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.searchQuery, isEmpty);
      });

      test('should handle empty search query', () {
        // Act
        viewModel.updateSearchQuery('');

        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.searchQuery, isEmpty);
      });

      test('should search with Swedish characters', () {
        // Act
        viewModel.updateSearchQuery('åsa ängström');

        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(
          viewModel.conversations[0].participantDisplayNames['search_user'],
          equals('Åsa Ängström'),
        );
      });

      test('should return empty list when no search results', () {
        // Act
        viewModel.updateSearchQuery('nonexistent');

        // Assert
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.hasConversations, isFalse);
      });
    });

    // BUT-1838, the twin leak. The list stopped SHOWING a message sent before
    // this member joined the group, but the search filter still matched on
    // `lastMessage.content` — so a late joiner could confirm words in that
    // message by typing them and watching the row appear or not. Same
    // disclosure, narrower door, and against the same decision ("a new member
    // sees only from now on"). `_applySearch` now searches an empty string
    // whenever `Conversation.canReadMessageAt` — the same predicate the row
    // itself asks — says the message is out of reach.
    group('Search respects the history cut-off (BUT-1838)', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final joinedAt = DateTime.utc(2026, 2, 1);
      // Strictly between the two, so a guard keyed on `createdAt` instead of
      // the member's own stamp would still match.
      final beforeJoin = DateTime.utc(2026, 1, 15);
      final afterJoin = DateTime.utc(2026, 2, 2);

      // Lives in the pre-join message, in a readable one, and in one title —
      // so the query cannot pass by matching nothing anywhere.
      const query = 'restaurang';

      Conversation groupConv({
        required String id,
        required String title,
        required String content,
        required DateTime sentAt,
      }) => ConversationBuilder.build(
        id: id,
        title: title,
        isGroup: true,
        participantIds: [testUserId, 'user2'],
        participantDisplayNames: {testUserId: 'Test User', 'user2': 'Erik'},
        createdAt: createdAt,
        groupId: 'chat-group-1',
        memberSince: {testUserId: joinedAt},
        lastMessage: MessageBuilder.build(
          content: content,
          sentAt: sentAt,
          senderId: 'user2',
          senderDisplayName: 'Erik',
        ),
      );

      final preJoin = groupConv(
        id: 'conv_prejoin',
        title: 'Middagsgänget',
        content: 'Vi bokar restaurangen redan nu',
        sentAt: beforeJoin,
      );
      final readable = groupConv(
        id: 'conv_readable',
        title: 'Fredagsklubben',
        content: 'Restaurangen är fullbokad',
        sentAt: afterJoin,
      );
      final titleMatch = groupConv(
        id: 'conv_title',
        title: 'Restauranggänget',
        content: 'Vi ses klockan sex',
        sentAt: afterJoin,
      );

      Future<void> seed(List<Conversation> conversations) async {
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero);
      }

      List<String> resultIds() =>
          viewModel.conversations.map((c) => c.id).toList();

      test(
        'a word that appears ONLY in a pre-join message matches no row, while '
        'the same word in a readable message and in a title still does',
        () async {
          await seed([preJoin, readable, titleMatch]);

          expect(
            preJoin.lastMessage!.content.toLowerCase().contains(query),
            isTrue,
            reason: 'premise: the hidden message really carries the word',
          );
          expect(
            preJoin.historyQueryStartFor(testUserId),
            equals(joinedAt),
            reason: 'premise: this member really has a history cut-off',
          );

          viewModel.updateSearchQuery(query);

          // One assertion, both directions: the two controls prove the query
          // works at all, and the hidden row's absence is the fix.
          expect(
            resultIds(),
            unorderedEquals(['conv_readable', 'conv_title']),
          );
        },
      );

      test(
        'a row whose last message is out of reach is still findable by its '
        'TITLE — the cut-off blanks the preview, it does not hide the group',
        () async {
          // The over-fix, and the one edit the other four tests in this group
          // all survive: `if (!canReadMessageAt(...)) return false;` as the
          // whole where-clause. Every fixture above pairs an unreadable
          // message with a title that does NOT match, so dropping the row and
          // dropping only its content are indistinguishable there.
          //
          // A late joiner is a full member of the group — the group's NAME is
          // not what the cut-off protects, and losing it means typing your own
          // group's name makes it disappear from the list. That is a worse
          // regression than the leak this guard closes, and it would ship
          // green.
          await seed([preJoin, titleMatch]);

          expect(
            preJoin.canReadMessageAt(
              preJoin.lastMessage!.sentAt,
              testUserId,
            ),
            isFalse,
            reason:
                'premise: this row\'s preview really is blanked, so the match '
                'below can only have come through the title',
          );

          viewModel.updateSearchQuery('middagsgänget');

          expect(resultIds(), equals(['conv_prejoin']));
        },
      );

      test(
        'a DIRECT conversation carrying a stamp is still searchable — the '
        'cut-off is selected by groupId, not by having a memberSince entry',
        () async {
          // The near-twin discriminator. `historyQueryStartFor` answers null
          // without a `groupId`, so this stamp is inert data and the rules
          // apply no history limit to a direct chat. A filter reading
          // `memberSince` directly silently makes a whole 1:1 history
          // unsearchable. This fixture does NOT separate `groupId == null` from
          // `!isGroup` — it has neither, so the two predicates agree; that
          // substitution is killed in the model suite's `canReadMessageAt`
          // group, on the legacy shape.
          final direct = ConversationBuilder.build(
            id: 'conv_direct_stamped',
            isGroup: false,
            participantIds: [testUserId, 'other_user'],
            participantDisplayNames: {
              testUserId: 'Test User',
              'other_user': 'Anna',
            },
            createdAt: createdAt,
            memberSince: {testUserId: joinedAt},
            lastMessage: MessageBuilder.build(
              content: 'Vi bokar restaurangen redan nu',
              sentAt: beforeJoin,
              senderId: 'other_user',
              senderDisplayName: 'Anna',
            ),
          );

          await seed([direct, titleMatch]);

          expect(
            direct.historyQueryStartFor(testUserId),
            isNull,
            reason: 'premise: no groupId, so no rule to mirror',
          );
          expect(
            direct.memberSince[testUserId],
            equals(joinedAt),
            reason:
                'premise: the stamp is present and later than the message, so '
                'a guard reading it directly would blank this row',
          );

          viewModel.updateSearchQuery(query);

          expect(
            resultIds(),
            unorderedEquals(['conv_direct_stamped', 'conv_title']),
          );
        },
      );

      test(
        'a message sent at the exact join instant stays searchable — the rule '
        'allows sentAt >= memberSince',
        () async {
          // The flip point. `!sentAt.isBefore(stamp)` is true here;
          // `sentAt.isAfter(stamp)` is not, and the chat screen shows this
          // message, so the search must find it.
          final boundary = groupConv(
            id: 'conv_boundary',
            title: 'Grillgänget',
            content: 'Restaurangen ligger vid torget',
            sentAt: joinedAt,
          );

          await seed([boundary, preJoin]);

          viewModel.updateSearchQuery(query);

          expect(resultIds(), equals(['conv_boundary']));
        },
      );

      test(
        'a group row carrying NO stamp for the searcher matches nothing — the '
        'filter fails CLOSED where historyQueryStartFor answers null',
        () async {
          // The state `stageMemberRemoval` leaves behind: it deletes
          // `memberSince.{uid}` and leaves `groupId` on the conversation. The
          // older predicate answers null here, which reads as "no cut-off,
          // search it"; `canReadMessageAt` answers false, like the rule's
          // `.get(uid, request.time)` default.
          final noStamp = ConversationBuilder.build(
            id: 'conv_no_stamp',
            title: 'Torsdagsgänget',
            isGroup: true,
            participantIds: [testUserId, 'user2'],
            participantDisplayNames: {testUserId: 'Test User', 'user2': 'Erik'},
            createdAt: createdAt,
            groupId: 'chat-group-1',
            // Somebody else's stamp, so an empty map cannot be the cause.
            memberSince: {'user2': createdAt},
            lastMessage: MessageBuilder.build(
              content: 'Vi bokar restaurangen redan nu',
              sentAt: afterJoin,
              senderId: 'user2',
              senderDisplayName: 'Erik',
            ),
          );

          await seed([noStamp, titleMatch]);

          expect(
            noStamp.historyQueryStartFor(testUserId),
            isNull,
            reason: 'premise: the searcher has no stamp of their own',
          );
          expect(
            noStamp.lastMessage!.sentAt.isAfter(joinedAt),
            isTrue,
            reason:
                'premise: the message is recent, so a match would not be '
                'explained by an ordinary pre-join cut-off',
          );

          viewModel.updateSearchQuery(query);

          expect(resultIds(), equals(['conv_title']));
        },
      );
    });

    group('Direct Conversation Creation', () {
      test('should create direct conversation successfully', () async {
        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
          otherUserAvatarUrl: 'https://example.com/avatar.jpg',
        );

        // Assert
        expect(conversationId, equals('new_conv_direct'));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);

        verify(
          () => mockMessagingService.startDirectConversation(
            otherUserId: 'other_user_123',
            otherUserDisplayName: 'Erik Eriksson',
            otherUserAvatarUrl: 'https://example.com/avatar.jpg',
          ),
        ).called(1);
      });

      test('should create direct conversation without avatar URL', () async {
        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );

        // Assert
        expect(conversationId, equals('new_conv_direct'));

        verify(
          () => mockMessagingService.startDirectConversation(
            otherUserId: 'other_user_123',
            otherUserDisplayName: 'Erik Eriksson',
            otherUserAvatarUrl: null,
          ),
        ).called(1);
      });

      test('should handle error during direct conversation creation', () async {
        // Arrange
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenThrow(Exception('Network error'));

        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );

        // Assert
        expect(conversationId, isNull);
        expect(viewModel.error, contains('Kunde inte starta konversation'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should set loading state during creation', () async {
        // Arrange
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasCreating = true;
        });

        // Act
        await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );

        // Assert
        expect(wasCreating, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should not create when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act
        final conversationId = await testViewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );

        // Assert
        expect(conversationId, isNull);
        verifyNever(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        );
      });

      test('should clear creation error on successful creation', () async {
        // Arrange - Set initial error
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenThrow(Exception('First attempt failed'));

        await viewModel.startDirectConversation(
          otherUserId: 'user1',
          otherUserDisplayName: 'User 1',
        );
        expect(viewModel.error, isNotNull);

        // Reset mock for successful attempt
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenAnswer((_) async => 'new_conv');

        // Act
        await viewModel.startDirectConversation(
          otherUserId: 'user2',
          otherUserDisplayName: 'User 2',
        );

        // Assert
        expect(viewModel.error, isNull);
      });
    });

    group('Group Conversation Creation', () {
      test('should create group conversation successfully', () async {
        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: ['user1', 'user2', 'user3'],
          participantDisplayNames: {
            'user1': 'Anna Andersson',
            'user2': 'Erik Svensson',
            'user3': 'Maria Öberg',
          },
          participantAvatarUrls: {
            'user1': 'https://example.com/anna.jpg',
            'user2': null,
            'user3': 'https://example.com/maria.jpg',
          },
          title: 'Matlagningsgruppen',
        );

        // Assert
        expect(conversationId, equals('new_conv_group'));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should handle multiple participants in group', () async {
        // Arrange
        final participantIds = List.generate(10, (i) => 'user$i');
        final displayNames = Map.fromEntries(
          participantIds.map((id) => MapEntry(id, 'User ${id.substring(4)}')),
        );
        final avatarUrls = Map.fromEntries(
          participantIds.map((id) => MapEntry(id, null)),
        );

        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: displayNames,
          participantAvatarUrls: avatarUrls,
          title: 'Stor grupp',
        );

        // Assert
        expect(conversationId, equals('new_conv_group'));

        verify(
          () => mockMessagingService.createGroupConversation(
            participantIds: participantIds,
            participantDisplayNames: displayNames,
            participantAvatarUrls: avatarUrls,
            title: 'Stor grupp',
          ),
        ).called(1);
      });

      test('should handle participant display names and avatars', () async {
        // Act
        await viewModel.createGroupConversation(
          participantIds: ['user1', 'user2'],
          participantDisplayNames: {
            'user1': 'Åsa Ängström',
            'user2': 'Örjan Öberg',
          },
          participantAvatarUrls: {
            'user1': 'https://example.com/asa.jpg',
            'user2': null,
          },
          title: 'Svenska tecken',
        );

        // Assert
        verify(
          () => mockMessagingService.createGroupConversation(
            participantIds: ['user1', 'user2'],
            participantDisplayNames: {
              'user1': 'Åsa Ängström',
              'user2': 'Örjan Öberg',
            },
            participantAvatarUrls: {
              'user1': 'https://example.com/asa.jpg',
              'user2': null,
            },
            title: 'Svenska tecken',
          ),
        ).called(1);
      });

      test('should handle error during group creation', () async {
        // Arrange
        when(
          () => mockMessagingService.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
          ),
        ).thenThrow(Exception('Creation failed'));

        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );

        // Assert
        expect(conversationId, isNull);
        expect(viewModel.error, contains('Kunde inte skapa gruppchatt'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should manage loading state during creation', () async {
        // Arrange
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasCreating = true;
        });

        // Act
        await viewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );

        // Assert
        expect(wasCreating, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should not create when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act
        final conversationId = await testViewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );

        // Assert
        expect(conversationId, isNull);
        verifyNever(
          () => mockMessagingService.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
          ),
        );
      });
    });

    group('Mark as Read', () {
      test('should mark conversation as read successfully', () async {
        // Act
        await viewModel.markConversationAsRead('conv_123');

        // Assert
        verify(
          () => mockMessagingService.markConversationAsRead('conv_123'),
        ).called(1);
      });

      test('should handle error silently when marking as read fails', () async {
        // Arrange
        when(
          () => mockMessagingService.markConversationAsRead(any()),
        ).thenThrow(Exception('Mark as read failed'));

        // Act & Assert - Should not throw
        await expectLater(
          viewModel.markConversationAsRead('conv_123'),
          completes,
        );

        // Error should not be visible to user
        expect(viewModel.error, isNull);
      });

      test('should handle marking invalid conversation ID', () async {
        // Act
        await viewModel.markConversationAsRead('');

        // Assert
        verify(() => mockMessagingService.markConversationAsRead('')).called(1);
      });

      test('should not mark as read when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act
        await testViewModel.markConversationAsRead('conv_123');

        // Assert
        verifyNever(() => mockMessagingService.markConversationAsRead(any()));
      });
    });

    group('Leave Group', () {
      test('should leave group successfully', () async {
        // Arrange — leaveGroup reads groupId off the loaded conversation.
        conversationsStreamController.add([leaveGroupConversation()]);
        await Future.delayed(Duration.zero);

        // Act
        final result = await viewModel.leaveGroup('group_123');

        // Assert
        expect(result, isTrue);
        verify(
          () => mockChatGroupRepository.removeMember(
            groupId: 'chatgroup_123',
            userId: null,
          ),
        ).called(1);
      });

      test('should handle when user not authenticated', () async {
        // Arrange
        conversationsStreamController.add([leaveGroupConversation()]);
        await Future.delayed(Duration.zero);
        final mockPermissionService =
            TestServiceLocator.get<PermissionService>()
                as FakePermissionService;
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );

        // Act
        final result = await viewModel.leaveGroup('group_123');

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        );
      });

      test('should fail when the conversation has no chat group', () async {
        // A conversation missing groupId (legacy data) cannot be left this
        // way — there is nothing to call removeMember on.
        conversationsStreamController.add([
          ConversationBuilder.buildGroup(id: 'group_nogroupid'),
        ]);
        await Future.delayed(Duration.zero);

        final result = await viewModel.leaveGroup('group_nogroupid');

        expect(result, isFalse);
        verifyNever(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        );
      });

      test('should handle error when leaving group', () async {
        // Arrange
        conversationsStreamController.add([leaveGroupConversation()]);
        await Future.delayed(Duration.zero);
        when(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        ).thenThrow(Exception('Leave failed'));

        // Act
        final result = await viewModel.leaveGroup('group_123');

        // Assert
        expect(result, isFalse);
      });

      test('should surface rate-limit wording on resource-exhausted', () async {
        // Arrange
        conversationsStreamController.add([leaveGroupConversation()]);
        await Future.delayed(Duration.zero);
        when(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        ).thenThrow(
          FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'Slow down.',
            details: const {'retryAfterSeconds': 12},
          ),
        );

        // Act
        final result = await viewModel.leaveGroup('group_123');

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, contains('12'));
      });

      test('should return correct success/failure values', () async {
        conversationsStreamController.add([
          leaveGroupConversation(
            id: 'group_success',
            groupId: 'chatgroup_success',
          ),
          leaveGroupConversation(id: 'group_fail', groupId: 'chatgroup_fail'),
        ]);
        await Future.delayed(Duration.zero);

        // Test success
        final successResult = await viewModel.leaveGroup('group_success');
        expect(successResult, isTrue);

        // Test failure
        when(
          () => mockChatGroupRepository.removeMember(
            groupId: 'chatgroup_fail',
            userId: any(named: 'userId'),
          ),
        ).thenThrow(Exception('Failed'));

        final failureResult = await viewModel.leaveGroup('group_fail');
        expect(failureResult, isFalse);
      });

      test('should not leave group when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act
        final result = await testViewModel.leaveGroup('group_123');

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        );
      });
    });

    group('Refresh & Error Management', () {
      test('should handle refresh with delay', () async {
        // Act
        final stopwatch = Stopwatch()..start();
        await viewModel.refresh();
        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(500));
      });

      test('should clear general error', () async {
        // Arrange - Set a stream error first
        conversationsStreamController.addError('Test error');
        await Future.delayed(Duration.zero); // Wait for error to be set
        expect(viewModel.conversationsError, isNotNull);

        // Act
        viewModel.clearAllErrors();

        // Assert
        expect(viewModel.conversationsError, isNull);
      });

      test('should clear conversation creation error', () async {
        // Arrange - Create an operation error
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenThrow(Exception('Creation error'));

        await viewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );
        expect(viewModel.error, isNotNull);

        // Act
        viewModel.clearAllErrors();

        // Assert
        expect(viewModel.error, isNull);
      });

      test('should handle multiple error states', () async {
        // Set stream error
        conversationsStreamController.addError('Stream error');
        await Future.delayed(Duration.zero);

        // Set creation error
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenThrow(Exception('Creation error'));

        await viewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );

        // Both errors should be set
        expect(viewModel.error, isNotNull);
        expect(viewModel.error, isNotNull);

        // Clear all errors
        viewModel.clearAllErrors();

        // Both should be cleared
        expect(viewModel.error, isNull);
        expect(viewModel.error, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // GRP-11 — edge cases for startDirectConversation
    // -----------------------------------------------------------------------
    group('Direct Conversation — edge cases', () {
      // Intent: when the service returns the SAME conversation ID for two calls
      // with the same participant (get-or-create contract), the VM must surface
      // that existing ID unchanged — it must not try to create a duplicate.
      test(
        'returns existing conversation ID when service returns same ID twice (get-or-create)',
        () async {
          when(
            () => mockMessagingService.startDirectConversation(
              otherUserId: 'known_user',
              otherUserDisplayName: 'Known User',
              otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
            ),
          ).thenAnswer((_) async => 'conv_existing_123');

          final first = await viewModel.startDirectConversation(
            otherUserId: 'known_user',
            otherUserDisplayName: 'Known User',
          );
          final second = await viewModel.startDirectConversation(
            otherUserId: 'known_user',
            otherUserDisplayName: 'Known User',
          );

          // Both calls must surface the same ID (no duplicate created).
          expect(first, equals('conv_existing_123'));
          expect(second, equals('conv_existing_123'));
          // The VM must have forwarded BOTH calls — the dedup is in the service.
          verify(
            () => mockMessagingService.startDirectConversation(
              otherUserId: 'known_user',
              otherUserDisplayName: 'Known User',
              otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
            ),
          ).called(2);
        },
      );

      // Intent: calling startDirectConversation with the current user's own ID
      // is an input the service layer is responsible for handling. The VM must
      // not silently swallow the resulting error — it must surface it so the
      // caller knows the operation failed rather than succeeding silently.
      test(
        'surfaces error when service rejects self-conversation attempt',
        () async {
          when(
            () => mockMessagingService.startDirectConversation(
              otherUserId: testUserId, // same as current user
              otherUserDisplayName: any(named: 'otherUserDisplayName'),
              otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
            ),
          ).thenThrow(Exception('Cannot start conversation with yourself'));

          final result = await viewModel.startDirectConversation(
            otherUserId: testUserId,
            otherUserDisplayName: 'Test User',
          );

          expect(result, isNull);
          expect(viewModel.error, isNotNull);
          expect(viewModel.isLoading, isFalse);
        },
      );

      // Intent: if the service succeeds after a prior error, the error state
      // must be cleared so the user does not see a stale error message alongside
      // a freshly opened conversation. (Regression guard for AsyncOperationMixin
      // error-clearing semantics — already proven for group creation above,
      // but the direct-conversation path goes through a separate executeAsync call.)
      test('clears prior error on successful retry', () async {
        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenThrow(Exception('Timeout'));

        await viewModel.startDirectConversation(
          otherUserId: 'user_a',
          otherUserDisplayName: 'User A',
        );
        expect(viewModel.error, isNotNull);

        when(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        ).thenAnswer((_) async => 'conv_retry');

        final result = await viewModel.startDirectConversation(
          otherUserId: 'user_a',
          otherUserDisplayName: 'User A',
        );

        expect(result, equals('conv_retry'));
        expect(viewModel.error, isNull);
      });
    });

    group('Lifecycle Management', () {
      test('should dispose and cancel stream subscription', () async {
        // Arrange
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );

        // Act & Assert - Should not throw on first dispose
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle safe notify listeners when disposed', () {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act & Assert - Should not throw
        expect(() => testViewModel.updateSearchQuery('test'), returnsNormally);
        expect(() => testViewModel.clearSearch(), returnsNormally);
        expect(() => testViewModel.clearAllErrors(), returnsNormally);
      });

      test('should handle multiple dispose calls safely', () {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );

        // Act - First dispose should work
        expect(() => testViewModel.dispose(), returnsNormally);

        // Note: Flutter's ChangeNotifier will throw on subsequent dispose calls
        // This is expected behavior, not a bug in our code
      });

      test('should not perform operations after dispose', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          chatGroupRepository: mockChatGroupRepository,
        );
        testViewModel.dispose();

        // Act
        testViewModel.updateSearchQuery('test');
        testViewModel.clearSearch();
        testViewModel.clearAllErrors();
        await testViewModel.refresh();
        await testViewModel.markConversationAsRead('conv');
        await testViewModel.leaveGroup('group');
        await testViewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );
        await testViewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Group',
        );

        // Assert - No operations should have been performed
        verifyNever(() => mockMessagingService.markConversationAsRead(any()));
        verifyNever(
          () => mockChatGroupRepository.removeMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
          ),
        );
        verifyNever(
          () => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          ),
        );
        verifyNever(
          () => mockMessagingService.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
          ),
        );
      });
    });
  });
}
