import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';

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

  static Conversation buildGroupConversation({
    String? id,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
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
      title: title ?? 'Gruppchatt',
      participantIds: ids,
      participantDisplayNames: names,
      isGroup: true,
    );
  }
}

class MessageBuilder {
  static Message build({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderDisplayName,
    MessageType type = MessageType.text,
    String? content,
    Map<String, dynamic>? data,
    DateTime? sentAt,
    DateTime? editedAt,
    String? replyToMessageId,
    Map<String, DateTime>? readBy,
    bool isDeleted = false,
  }) {
    final now = DateTime.now();

    return Message(
      id: id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId ?? 'conv_123',
      senderId: senderId ?? 'user1',
      senderDisplayName: senderDisplayName ?? 'Anna Andersson',
      senderAvatarUrl: null,
      type: type,
      content: content ?? 'Test message',
      status: MessageStatus.delivered,
      metadata: data,
      sentAt: sentAt ?? now,
      editedAt: editedAt,
      replyToMessageId: replyToMessageId,
      isEdited: isDeleted,
    );
  }

  static Message buildRecipeShare({
    String? id,
    String? senderId,
    String? recipeId,
    String? recipeTitle,
    String? message,
  }) {
    return build(
      id: id,
      senderId: senderId,
      type: MessageType.recipeShare,
      content: message ?? 'Kolla in detta recept!',
      data: {
        'recipeId': recipeId ?? 'recipe_123',
        'recipeTitle': recipeTitle ?? 'Köttbullar med gräddsås',
      },
    );
  }
}

class MockPresenceService extends Mock implements PresenceService {}

void main() {
  group('ChatViewModel', () {
    late ChatViewModel viewModel;
    late MockMessagingService mockMessagingService;
    late FakeAuthRepository mockAuthRepository;
    late MockPresenceService mockPresenceService;
    // ignore: close_sinks
    late StreamController<List<Message>> messagesStreamController;
    const testConversationId = 'conv_test_123';
    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ConversationBuilder.build());
      registerFallbackValue(MessageBuilder.build());

      // Bridge production ServiceLocator to test GetIt instance
      // so ChatViewModel.currentUserId can resolve PermissionService
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockMessagingService = MockMessagingService();
      mockAuthRepository = FakeAuthRepository();
      mockPresenceService = MockPresenceService();
      messagesStreamController = StreamController<List<Message>>.broadcast();

      // Configure auth repository
      mockAuthRepository.setAuthState(
        isAuthenticated: true,
        userId: testUserId,
      );

      // Configure the messaging service with a message stream
      messagesStreamController = mockMessagingService.createMessageStream(
        testConversationId,
      );

      // Setup default mock behaviors
      when(() => mockMessagingService.getConversation(any())).thenAnswer(
        (_) async => ConversationBuilder.build(
          id: testConversationId,
          participantIds: [testUserId, 'user2'],
        ),
      );

      when(
        () => mockMessagingService.getConversationMessages(
          conversationId: any(named: 'conversationId'),
          historyStart: any(named: 'historyStart'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => messagesStreamController.stream);

      when(
        () => mockMessagingService.sendTextMessage(
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          replyToMessageId: any(named: 'replyToMessageId'),
        ),
      ).thenAnswer((_) async => MessageBuilder.build());

      when(
        () => mockMessagingService.sendRecipeShare(
          conversationId: any(named: 'conversationId'),
          recipeId: any(named: 'recipeId'),
          recipeTitle: any(named: 'recipeTitle'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async => MessageBuilder.buildRecipeShare());

      when(
        () => mockMessagingService.deleteMessage(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockMessagingService.markConversationAsRead(any()),
      ).thenAnswer((_) async {});

      when(
        () => mockMessagingService.setTypingIndicator(any()),
      ).thenAnswer((_) async {});

      when(
        () => mockMessagingService.clearTypingIndicator(any()),
      ).thenAnswer((_) async {});

      // Configure presence service for typing indicators
      when(
        () => mockPresenceService.startTyping(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockPresenceService.stopTyping(any()),
      ).thenAnswer((_) async {});

      // Register mocks in test service locator
      TestServiceLocator.registerMock<MessagingService>(mockMessagingService);
      TestServiceLocator.registerMock<AuthRepository>(mockAuthRepository);

      // Configure PermissionService with test user ID so
      // ChatViewModel.currentUserId resolves correctly via production ServiceLocator
      final permissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      permissionService.setPermissionState(currentUserId: testUserId);

      // Configure UnifiedFriendsService so _checkFriendshipStatus sees
      // 'user2' as a friend (otherwise canSendMessages returns false).
      final friendsService =
          TestServiceLocator.get<UnifiedFriendsService>()
              as MockUnifiedFriendsService;
      final managementMock = MockFriendsManagementOperations();
      managementMock.setManagementState(
        friends: [
          UserProfile(
            uid: 'user2',
            displayName: 'Anna Andersson',
            email: 'anna@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ],
      );
      friendsService.setFriendsState(management: managementMock);

      // Create viewModel with initial conversation to avoid async loading in setup
      final initialConversation = ConversationBuilder.build(
        id: testConversationId,
        participantIds: [testUserId, 'user2'],
        participantDisplayNames: {
          testUserId: 'Test User',
          'user2': 'Anna Andersson',
        },
      );

      viewModel = ChatViewModel(
        authRepository: FakeAuthRepository(),
        maturityHelper: FakeMaturedAccountHelper(),
        messagingService: mockMessagingService,
        conversationId: testConversationId,
        initialConversation: initialConversation,
        presenceService: mockPresenceService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      mockMessagingService.disposeStreams();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.conversationId, equals(testConversationId));
        expect(viewModel.messages, isEmpty);
        expect(viewModel.isLoading, isTrue); // Still loading messages initially
        expect(viewModel.error, isNull);
        expect(viewModel.isSending, isFalse);
        expect(viewModel.sendError, isNull);
        expect(viewModel.typingUserNames, isEmpty);
        expect(viewModel.currentUserId, equals(testUserId));
        expect(viewModel.replyToMessage, isNull);
        expect(viewModel.conversation, isNotNull); // Has initial conversation
      });

      test(
        'should load conversation on initialization when not provided',
        () async {
          // Arrange
          final testConversation = ConversationBuilder.build(
            id: testConversationId,
            title: 'Test Chatt',
          );
          when(
            () => mockMessagingService.getConversation(testConversationId),
          ).thenAnswer((_) async => testConversation);

          // Act - create viewModel without initial conversation
          final newViewModel = ChatViewModel(
            authRepository: FakeAuthRepository(),
            maturityHelper: FakeMaturedAccountHelper(),
            messagingService: mockMessagingService,
            conversationId: testConversationId,
          );
          await Future.delayed(const Duration(milliseconds: 100));

          // Assert
          verify(
            () => mockMessagingService.getConversation(testConversationId),
          ).called(1);

          // Clean up
          newViewModel.dispose();
        },
      );

      test('should initialize with provided conversation', () {
        // Arrange
        final initialConversation = ConversationBuilder.build(
          id: testConversationId,
          title: 'Initial Chatt',
          participantIds: [testUserId, 'user2'],
        );

        // Act
        final newViewModel = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: initialConversation,
        );

        // Assert
        expect(newViewModel.conversation, equals(initialConversation));

        // Clean up
        newViewModel.dispose();
      });

      test('should setup message stream subscription', () async {
        // Arrange - done in setUp

        // Act - trigger messages update
        final messages = [
          MessageBuilder.build(content: 'Hej!'),
          MessageBuilder.build(content: 'Hur mår du?'),
        ];
        messagesStreamController.add(messages);

        // Wait for stream to propagate
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - after stream event
        expect(viewModel.messages.length, equals(2));
      });

      // BUT-1838: a group conversation's history cut-off must reach the
      // message query — firestore.rules refuses any message sent before the
      // member joined, and a query missing that filter fails ENTIRELY, not
      // partially. This is the regression the fix targets.
      test(
        'passes historyQueryStartFor(currentUser) to the message stream for a '
        'group conversation',
        () async {
          // `createdAt` must PRECEDE the stamp, or this fixture describes a
          // member who joined before the group existed — and
          // `joinedLaterAt` returns null for anyone whose stamp is not after
          // creation, because `createChatGroup` stamps every FOUNDING member
          // with the conversation's own `createdAt` and a founder must not get
          // a "Du gick med här" divider. Left at the builder's default (now),
          // this test would silently assert the founder case instead.
          final createdAt = DateTime(2026, 1, 1);
          final joinedAt = DateTime(2026, 1, 15);
          final groupConversation = ConversationBuilder.build(
            id: 'conv_group_history',
            participantIds: [testUserId, 'user2'],
            isGroup: true,
            groupId: 'chatgroup-1',
            createdAt: createdAt,
            memberSince: {testUserId: joinedAt},
          );

          final newViewModel = ChatViewModel(
            authRepository: FakeAuthRepository(),
            maturityHelper: FakeMaturedAccountHelper(),
            messagingService: mockMessagingService,
            conversationId: 'conv_group_history',
            initialConversation: groupConversation,
            presenceService: mockPresenceService,
          );
          await Future.delayed(const Duration(milliseconds: 50));

          verify(
            () => mockMessagingService.getConversationMessages(
              conversationId: 'conv_group_history',
              historyStart: joinedAt,
              limit: any(named: 'limit'),
            ),
          ).called(1);

          newViewModel.dispose();
        },
      );

      test(
        'passes a null historyStart for a direct conversation',
        () async {
          // The default setUp conversation is a direct chat (isGroup: false,
          // no groupId) — historyQueryStartFor always returns null for it.
          //
          // NOTE this one is a RECALL CONTROL, not a discriminator: dropping
          // the `historyStart:` argument entirely also yields null (it is the
          // parameter's default), so this test cannot see that mutant. The
          // group test above is what kills it.
          await Future.delayed(const Duration(milliseconds: 50));
          verify(
            () => mockMessagingService.getConversationMessages(
              conversationId: testConversationId,
              historyStart: null,
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      // BUT-1838, the ORDERING half. The test above passes
      // `initialConversation`, which resolves the conversation synchronously
      // and so cannot see WHEN the stream is opened — measured: reverting
      // `_initializeChat` to the old fire-and-forget
      // `_loadConversation(); _loadMessages();` left this file green. On a COLD open (no initialConversation — how the chat is
      // actually entered from the conversations list) that revert opens the
      // message stream before `memberSince` is known, so the cut-off is null,
      // the query returns rows firestore.rules refuses, and the WHOLE query
      // fails. This test omits initialConversation on purpose; it is the only
      // thing in the file that constrains the ordering.
      test(
        'a COLD open waits for the conversation before opening the message '
        'stream, so the cut-off is never null for a late joiner',
        () async {
          final joinedAt = DateTime(2026, 2, 20);
          final loadStarted = Completer<void>();
          final releaseLoad = Completer<void>();

          when(
            () => mockMessagingService.getConversation('conv_cold_open'),
          ).thenAnswer((_) async {
            if (!loadStarted.isCompleted) loadStarted.complete();
            // Hold the conversation fetch open. If the stream is opened
            // without waiting, it happens while we are parked here — which
            // is exactly what the premise assertion below detects.
            await releaseLoad.future;
            return ConversationBuilder.build(
              id: 'conv_cold_open',
              participantIds: [testUserId, 'user2'],
              isGroup: true,
              groupId: 'chatgroup-cold',
              // Before the stamp — see the note on the sibling fixture: a
              // member whose stamp is not AFTER creation is a founder, and a
              // founder deliberately has no cut-off.
              createdAt: DateTime(2026, 1, 1),
              memberSince: {testUserId: joinedAt},
            );
          });

          final coldViewModel = ChatViewModel(
            authRepository: FakeAuthRepository(),
            maturityHelper: FakeMaturedAccountHelper(),
            messagingService: mockMessagingService,
            conversationId: 'conv_cold_open',
            presenceService: mockPresenceService,
          );

          await loadStarted.future;
          await Future.delayed(const Duration(milliseconds: 20));

          // Premise: while the conversation is still loading, NO message
          // query has been opened. Without this the test would pass on the
          // reverted ordering too, since the verify below only inspects the
          // eventual call.
          verifyNever(
            () => mockMessagingService.getConversationMessages(
              conversationId: 'conv_cold_open',
              historyStart: any(named: 'historyStart'),
              limit: any(named: 'limit'),
            ),
          );

          releaseLoad.complete();
          await Future.delayed(const Duration(milliseconds: 50));

          // ...and once it resolves, the stream opens WITH the cut-off.
          verify(
            () => mockMessagingService.getConversationMessages(
              conversationId: 'conv_cold_open',
              historyStart: joinedAt,
              limit: any(named: 'limit'),
            ),
          ).called(1);

          coldViewModel.dispose();
        },
      );
    });

    group('State Accessors', () {
      test('should return conversation title', () {
        // Arrange - create a GROUP conversation to use custom title
        final conversation = ConversationBuilder.buildGroupConversation(
          id: testConversationId,
          title: 'Test Grupp',
          participantIds: [testUserId, 'user2', 'user3'],
          participantDisplayNames: {
            testUserId: 'Jag',
            'user2': 'Anna',
            'user3': 'Erik',
          },
        );
        final vmWithConversation = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: conversation,
        );

        // Act & Assert
        expect(vmWithConversation.conversationTitle, equals('Test Grupp'));

        // Clean up
        vmWithConversation.dispose();
      });

      test('should return loading title when no conversation', () {
        // Arrange - create viewModel without initial conversation
        final vmWithoutConversation = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
        );

        // Act & Assert
        expect(vmWithoutConversation.conversationTitle, equals('Laddar...'));

        // Clean up
        vmWithoutConversation.dispose();
      });

      test('should return conversation subtitle for group', () {
        // Arrange
        final groupConversation = ConversationBuilder.buildGroupConversation();
        final vmWithGroup = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: groupConversation,
        );

        // Act & Assert
        expect(vmWithGroup.conversationSubtitle, equals('3 deltagare'));

        // Clean up
        vmWithGroup.dispose();
      });
    });

    group('Message Operations', () {
      test('should send text message successfully', () async {
        // Arrange
        const messageContent = 'Hej allihopa!';

        // Act
        final result = await viewModel.sendTextMessage(messageContent);

        // Assert
        expect(result, isTrue);
        expect(viewModel.isSending, isFalse);
        expect(viewModel.sendError, isNull);
        verify(
          () => mockMessagingService.sendTextMessage(
            conversationId: testConversationId,
            content: messageContent,
            replyToMessageId: null,
          ),
        ).called(1);
      });

      test('should reject a profane message at the gate (BUT-1393)', () async {
        // Register the real content filter so the profanity gate is active, then
        // build a fresh VM (ChatViewModel captures ContentFilterService in its
        // constructor via ServiceLocator).
        TestServiceLocator.registerMock<ContentFilterService>(
          ContentFilterService(),
        );
        final guardedVm = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: ConversationBuilder.build(
            id: testConversationId,
            participantIds: [testUserId, 'user2'],
          ),
          presenceService: mockPresenceService,
        );

        // 'fan' is on the Swedish profanity list (see content_filter_service_test).
        final result = await guardedVm.sendTextMessage('din jävla fan');

        // Blocked before reaching the messaging service.
        expect(result, isFalse);
        expect(guardedVm.sendError, isNotNull);
        verifyNever(
          () => mockMessagingService.sendTextMessage(
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        );
        guardedVm.dispose();
      });

      test('should reject empty message', () async {
        // Arrange
        const emptyMessage = '  ';

        // Act
        final result = await viewModel.sendTextMessage(emptyMessage);

        // Assert
        expect(result, isFalse);
        expect(viewModel.sendError, equals('Meddelandet kan inte vara tomt'));
        verifyNever(
          () => mockMessagingService.sendTextMessage(
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        );
      });

      test('should handle send message error', () async {
        // Arrange
        when(
          () => mockMessagingService.sendTextMessage(
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        ).thenThrow(Exception('Network error'));

        // Act
        final result = await viewModel.sendTextMessage('Test');

        // Assert
        expect(result, isFalse);
        expect(viewModel.sendError, contains('Kunde inte skicka meddelande'));
        expect(viewModel.isSending, isFalse);
      });

      test('should send recipe share successfully', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const recipeTitle = 'Köttbullar';
        const message = 'Prova detta!';

        // Act
        final result = await viewModel.sendRecipeShare(
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          message: message,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockMessagingService.sendRecipeShare(
            conversationId: testConversationId,
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            message: message,
          ),
        ).called(1);
      });

      test('should delete message successfully', () async {
        // Arrange
        const messageId = 'msg_123';

        // Act
        final result = await viewModel.deleteMessage(messageId);

        // Assert
        expect(result, isTrue);
        verify(() => mockMessagingService.deleteMessage(messageId)).called(1);
      });

      test('should handle delete message error', () async {
        // Arrange
        when(
          () => mockMessagingService.deleteMessage(any()),
        ).thenThrow(Exception('Permission denied'));

        // Act
        final result = await viewModel.deleteMessage('msg_123');

        // Assert
        expect(result, isFalse);
      });
    });

    group('Poll Operations', () {
      Message buildPollMessage({
        required String id,
        required bool allowMultipleChoices,
      }) {
        return MessageBuilder.build(
          id: id,
          type: MessageType.poll,
          content: 'Vad ska vi äta?',
          data: {
            'poll': {
              'id': 'poll_$id',
              'question': 'Vad ska vi äta?',
              'allowMultipleChoices': allowMultipleChoices,
              'creatorId': 'user2',
              'createdAt': DateTime.now().toIso8601String(),
              'options': [
                {'id': 'opt_a', 'text': 'Pizza', 'voterIds': <String>[]},
                {'id': 'opt_b', 'text': 'Tacos', 'voterIds': <String>[]},
              ],
            },
          },
        );
      }

      setUp(() {
        when(
          () => mockMessagingService.votePoll(
            messageId: any(named: 'messageId'),
            optionId: any(named: 'optionId'),
            allowMultiple: any(named: 'allowMultiple'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessagingService.closePoll(
            messageId: any(named: 'messageId'),
          ),
        ).thenAnswer((_) async {});
      });

      test(
        'votePoll resolves allowMultiple=true from the poll metadata',
        () async {
          // Arrange — a multi-choice poll arrives over the stream
          final poll = buildPollMessage(id: 'p1', allowMultipleChoices: true);
          messagesStreamController.add([poll]);
          await Future.delayed(const Duration(milliseconds: 50));

          // Act
          await viewModel.votePoll('p1', 'opt_a');

          // Assert — the flag read from metadata is forwarded to the service
          verify(
            () => mockMessagingService.votePoll(
              messageId: 'p1',
              optionId: 'opt_a',
              allowMultiple: true,
            ),
          ).called(1);
        },
      );

      test(
        'votePoll resolves allowMultiple=false for single-choice polls',
        () async {
          // Arrange
          final poll = buildPollMessage(id: 'p2', allowMultipleChoices: false);
          messagesStreamController.add([poll]);
          await Future.delayed(const Duration(milliseconds: 50));

          // Act
          await viewModel.votePoll('p2', 'opt_b');

          // Assert
          verify(
            () => mockMessagingService.votePoll(
              messageId: 'p2',
              optionId: 'opt_b',
              allowMultiple: false,
            ),
          ).called(1);
        },
      );

      // ── BUT-1917: votePoll must stop swallowing too ───────────────────
      //
      // `firestore.rules` now denies a vote from someone a participant has
      // blocked. Before these tests the method logged and returned, so that
      // denial reached the user as a button that does nothing at all.

      test('votePoll returns null when the vote goes through', () async {
        final poll = buildPollMessage(id: 'p3', allowMultipleChoices: false);
        messagesStreamController.add([poll]);
        await Future.delayed(const Duration(milliseconds: 50));

        // The CONTROL. Without it the test below could be satisfied by a
        // method that returns the sentence unconditionally.
        expect(await viewModel.votePoll('p3', 'opt_a'), isNull);
      });

      test('votePoll returns a sentence when the service refuses', () async {
        final poll = buildPollMessage(id: 'p4', allowMultipleChoices: false);
        messagesStreamController.add([poll]);
        await Future.delayed(const Duration(milliseconds: 50));
        when(
          () => mockMessagingService.votePoll(
            messageId: any(named: 'messageId'),
            optionId: any(named: 'optionId'),
            allowMultiple: any(named: 'allowMultiple'),
          ),
        ).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final problem = await viewModel.votePoll('p4', 'opt_a');

        // The literal, not the symbol. Asserting against
        // `AppLocale.current.pollVoteFailed` would read the same getter on
        // both sides, so it would stay green if the viewmodel returned a
        // hard-coded Dart string — it pins nothing about where the sentence
        // comes from. The sibling `closePoll` tests type their Swedish out for
        // the same reason.
        expect(problem, 'Din röst kunde inte registreras.');
      });

      // The acceptance criterion, as its own test: the sentence a refused
      // voter reads must not disclose that a block exists.
      //
      // BOTH locales. `AppLocale.current` is Swedish in this harness
      // (`AppLocale._current` is initialised to `AppLocalizationsSv()` at field
      // level and nothing here re-initialises it), so reading it would leave
      // the English string unguarded.
      test('the refusal sentence never mentions blocking, in any locale', () {
        // 'blocker' is deliberately absent: any string containing it contains
        // 'block', so it could never fail on its own.
        for (final l10n in [AppLocalizationsSv(), AppLocalizationsEn()]) {
          final sentence = l10n.pollVoteFailed.toLowerCase();
          for (final word in ['block', 'spärr']) {
            expect(
              sentence.contains(word),
              isFalse,
              reason:
                  'a blocked person learning they were blocked is the '
                  'notification the silent design exists to avoid; "$word" '
                  'would leak it',
            );
          }
        }
      });

      // ── BUT-1908: closePoll must stop swallowing ──────────────────────
      //
      // It used to catch everything into a log line, which made the refusals
      // `MessagingService.closePoll` now raises invisible: the user taps
      // "avsluta", nothing happens, and there is no way to tell a refusal from
      // a slow network. A guard built without changing this method would BE the
      // silent failure it was meant to replace.
      //
      // The viewmodel returns the sentence to show and never rethrows — the
      // caller is a tap handler, and an uncaught async throw there is a crash.

      test('closePoll returns null when the poll actually closed', () async {
        // The control for the refusal cases below: without it, a method that
        // returned a message unconditionally would satisfy them.
        expect(await viewModel.closePoll('p1'), isNull);
      });

      test(
        'closePoll refuses locally when the poll on screen was never read',
        () async {
          // The CAPPED case, which the SERVICE cannot catch:
          // `MessagingService.closePoll` re-reads through `getMessage`, whose
          // list holds ONE message, so the cap is a no-op there and the poll
          // arrives marked `ok`. The widget hides the button on this state too
          // (`poll_message_widget_hydration_test.dart`); this gate is what
          // stops a close that reaches the viewmodel by any other route.
          final poll = buildPollMessage(
            id: 'p_capped',
            allowMultipleChoices: false,
          );
          messagesStreamController.add([
            poll.copyWith(
              metadata: <String, dynamic>{
                ...?poll.metadata,
                PollVoteHydration.metadataKey: PollVoteHydration.capped.name,
              },
            ),
          ]);
          await Future.delayed(const Duration(milliseconds: 50));

          final message = await viewModel.closePoll('p_capped');

          expect(message, contains('rösterna har inte hämtats'));
          verifyNever(
            () => mockMessagingService.closePoll(
              messageId: any(named: 'messageId'),
            ),
          );
        },
      );

      test('closePoll surfaces the unread-votes refusal in Swedish', () async {
        when(
          () => mockMessagingService.closePoll(
            messageId: any(named: 'messageId'),
          ),
        ).thenThrow(
          const PollCloseRefusedException(PollCloseRefusal.votesUnread),
        );

        final message = await viewModel.closePoll('p1');

        expect(message, isNotNull);
        expect(message, contains('rösterna har inte hämtats'));
      });

      test('closePoll tells the refusals apart', () async {
        // The whole reason the refusal carries a reason: one sentence for all of
        // them would be wrong for whichever user got a different one.
        //
        // BUT-1922: assert on `kunde inte läsas`, NOT on `blockeringslista`.
        // Both block-list strings contain the latter, so keying on it would let
        // this arm be repointed at the offline copy and stay green.
        when(
          () => mockMessagingService.closePoll(
            messageId: any(named: 'messageId'),
          ),
        ).thenThrow(
          const PollCloseRefusedException(PollCloseRefusal.blockListUnknown),
        );

        final message = await viewModel.closePoll('p1');

        expect(message, contains('kunde inte läsas'));
        expect(message, isNot(contains('rösterna har inte hämtats')));
        expect(message, isNot(contains('offline')));
      });

      test(
        'closePoll says OFFLINE rather than "try again" (BUT-1922)',
        () async {
          // Exhaustiveness proves the enum value is HANDLED, never that it is
          // handled with the right string — swapping the two block-list arms
          // compiles green and ships the wrong Swedish. The user-visible half of
          // BUT-1922 lives here and nowhere else.
          when(
            () => mockMessagingService.closePoll(
              messageId: any(named: 'messageId'),
            ),
          ).thenThrow(
            const PollCloseRefusedException(PollCloseRefusal.blockListOffline),
          );

          final message = await viewModel.closePoll('p1');

          expect(message, contains('offline'));
          expect(
            message,
            isNot(contains('kunde inte läsas')),
            reason:
                'telling an offline user their list "could not be read" sends '
                'them at a retry that cannot work until the connection is back',
          );
        },
      );

      test('closePoll reports an unexpected failure rather than swallowing '
          'it', () async {
        // The arm that existed before and produced nothing at all.
        when(
          () => mockMessagingService.closePoll(
            messageId: any(named: 'messageId'),
          ),
        ).thenThrow(Exception('boom'));

        expect(await viewModel.closePoll('p1'), isNotNull);
      });

      test('votePoll is a no-op when the message is not in the list', () async {
        // Act — vote for a message id that never arrived
        await viewModel.votePoll('missing', 'opt_a');

        // Assert — nothing reaches the service (no poll metadata to resolve)
        verifyNever(
          () => mockMessagingService.votePoll(
            messageId: any(named: 'messageId'),
            optionId: any(named: 'optionId'),
            allowMultiple: any(named: 'allowMultiple'),
          ),
        );
      });

      test(
        'votePoll is a no-op when the message carries no poll metadata',
        () async {
          // Arrange — a plain text message (no 'poll' key) under the target id
          messagesStreamController.add([
            MessageBuilder.build(id: 'plain', content: 'hej'),
          ]);
          await Future.delayed(const Duration(milliseconds: 50));

          // Act
          await viewModel.votePoll('plain', 'opt_a');

          // Assert — the second guard (missing poll metadata) blocks the call
          verifyNever(
            () => mockMessagingService.votePoll(
              messageId: any(named: 'messageId'),
              optionId: any(named: 'optionId'),
              allowMultiple: any(named: 'allowMultiple'),
            ),
          );
        },
      );

      test('closePoll delegates to the messaging service', () async {
        // Act
        await viewModel.closePoll('p1');

        // Assert
        verify(() => mockMessagingService.closePoll(messageId: 'p1')).called(1);
      });
    });

    group('Reply Functionality', () {
      test('should set reply to message', () {
        // Arrange
        final message = MessageBuilder.build(
          id: 'msg_reply',
          content: 'Original message',
        );
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setReplyToMessage(message);

        // Assert
        expect(viewModel.replyToMessage, equals(message));
        expect(viewModel.hasReplyTarget, isTrue);
        expect(notificationCount, greaterThan(0));
      });

      test('should clear reply to message', () {
        // Arrange
        final message = MessageBuilder.build();
        viewModel.setReplyToMessage(message);

        // Act
        viewModel.clearReplyToMessage();

        // Assert
        expect(viewModel.replyToMessage, isNull);
        expect(viewModel.hasReplyTarget, isFalse);
      });

      test('should send reply with reference', () async {
        // Arrange
        final originalMessage = MessageBuilder.build(id: 'original_msg');
        viewModel.setReplyToMessage(originalMessage);
        const replyContent = 'Detta är ett svar';

        // Act
        final result = await viewModel.sendReply(content: replyContent);

        // Assert
        expect(result, isTrue);
        expect(viewModel.replyToMessage, isNull); // Should clear after sending
        verify(
          () => mockMessagingService.sendTextMessage(
            conversationId: testConversationId,
            content: replyContent,
            replyToMessageId: 'original_msg',
          ),
        ).called(1);
      });

      test('should not send reply without target', () async {
        // Arrange - no reply target set

        // Act
        final result = await viewModel.sendReply(content: 'Test reply');

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockMessagingService.sendTextMessage(
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        );
      });

      test('should clear reply after successful send', () async {
        // Arrange
        final message = MessageBuilder.build();
        viewModel.setReplyToMessage(message);

        // Act
        await viewModel.sendTextMessage('Reply text');

        // Assert
        expect(viewModel.replyToMessage, isNull);
      });
    });

    group('Typing Indicators', () {
      test('should set typing indicator', () {
        // Arrange & Act
        viewModel.setTyping();

        // Assert - typing now uses PresenceService, not MessagingService
        verify(
          () => mockPresenceService.startTyping(testConversationId),
        ).called(1);
      });

      test('should clear typing indicator', () {
        // Arrange & Act
        viewModel.clearTyping();

        // Assert - typing now uses PresenceService, not MessagingService
        verify(
          () => mockPresenceService.stopTyping(testConversationId),
        ).called(1);
      });
    });

    group('Message Stream Handling', () {
      test('should update messages from stream', () async {
        // Arrange
        final messages = [
          MessageBuilder.build(content: 'Första'),
          MessageBuilder.build(content: 'Andra'),
          MessageBuilder.build(content: 'Tredje'),
        ];

        // Act
        messagesStreamController.add(messages);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(viewModel.messages, equals(messages));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasMessages, isTrue);
      });

      test('should handle stream error', () async {
        // Arrange & Act
        messagesStreamController.addError('Connection lost');
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(viewModel.error, equals('Kunde inte ladda meddelanden'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should mark conversation as read when messages arrive', () async {
        // Arrange
        final messages = [MessageBuilder.build()];

        // Act
        messagesStreamController.add(messages);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(
          () => mockMessagingService.markConversationAsRead(testConversationId),
        ).called(1);
      });
    });

    group('UI Helper Methods', () {
      test('should determine avatar visibility for messages', () {
        // Arrange
        final message1 = MessageBuilder.build(senderId: 'user2');
        final message2 = MessageBuilder.build(senderId: 'user2');
        final message3 = MessageBuilder.build(senderId: 'user3');

        // Act & Assert
        expect(
          viewModel.shouldShowAvatar(message1, null),
          isTrue,
        ); // First message
        expect(
          viewModel.shouldShowAvatar(message2, message1),
          isFalse,
        ); // Same sender
        expect(
          viewModel.shouldShowAvatar(message3, message2),
          isTrue,
        ); // Different sender
      });

      test('should not show avatar for own messages', () {
        // Arrange
        final ownMessage = MessageBuilder.build(senderId: testUserId);

        // Act & Assert
        expect(viewModel.shouldShowAvatar(ownMessage, null), isFalse);
      });

      test('should get message at index', () async {
        // Arrange
        final messages = [
          MessageBuilder.build(content: 'First'),
          MessageBuilder.build(content: 'Second'),
        ];
        messagesStreamController.add(messages);

        // Wait for stream to update
        await Future.delayed(const Duration(milliseconds: 50));

        // Act & Assert
        expect(viewModel.getMessageAt(0)?.content, equals('First'));
        expect(viewModel.getMessageAt(1)?.content, equals('Second'));
        expect(viewModel.getMessageAt(2), isNull);
        expect(viewModel.getMessageAt(-1), isNull);
      });

      test('should get previous message', () async {
        // Arrange
        final messages = [
          MessageBuilder.build(content: 'First'),
          MessageBuilder.build(content: 'Second'),
        ];
        messagesStreamController.add(messages);

        // Wait for stream to update
        await Future.delayed(const Duration(milliseconds: 50));

        // Act & Assert
        expect(viewModel.getPreviousMessage(0), isNull);
        expect(viewModel.getPreviousMessage(1)?.content, equals('First'));
      });
    });

    group('Error Handling', () {
      test('should clear all errors', () {
        // Arrange - set some errors
        viewModel
            .clearSendError(); // This sets sendError through private method

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.sendError, isNull);
      });

      test('should clear send error only', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearSendError();

        // Assert
        expect(viewModel.sendError, isNull);
        expect(notificationCount, greaterThan(0));
      });

      test('should handle conversation load error', () async {
        // Arrange
        when(
          () => mockMessagingService.getConversation(any()),
        ).thenThrow(Exception('Not found'));

        // Act
        final newViewModel = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: 'invalid_id',
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(newViewModel.error, equals('Kunde inte ladda konversation'));

        // Clean up
        newViewModel.dispose();
      });

      // BUT-1838. The sibling test above drives the THROW path; this one drives
      // the RETURN-NULL path, and they are different lines in different
      // branches. Nothing in this file stubbed `getConversation` to null before
      // — the only stub is the wildcard in setUp, which answers a conversation
      // — so deleting the `if (_conversation == null) setError(...)` check left
      // all of it green.
      //
      // Null is the NORMAL shape of a failure here, not an edge: the query
      // module catches and returns null, then MessagingService catches and
      // returns null again, so a permission-denied, an offline read and a
      // deleted document all arrive this way with no exception. Both readers
      // wait for the value — `_loadMessages` here and `ChatMessageStream`'s
      // `_awaitConversation`, which completes on `conversation != null ||
      // hasError` — so a null reporting neither leaves the chat on a spinner
      // with no error text and no retry, forever.
      test(
        'a null conversation is reported as an error, not resolved silently',
        () async {
          // Registered after setUp's wildcard, so this one wins (mocktail is
          // last-registered-wins).
          when(
            () => mockMessagingService.getConversation('conv_missing'),
          ).thenAnswer((_) async => null);

          final newViewModel = ChatViewModel(
            authRepository: FakeAuthRepository(),
            maturityHelper: FakeMaturedAccountHelper(),
            messagingService: mockMessagingService,
            conversationId: 'conv_missing',
          );
          await Future.delayed(const Duration(milliseconds: 100));

          expect(
            newViewModel.conversation,
            isNull,
            reason: 'premise: the service really did answer null',
          );
          expect(
            newViewModel.hasError,
            isTrue,
            reason:
                'this is the flag ChatMessageStream waits on; false here is '
                'the permanent spinner',
          );
          expect(newViewModel.error, equals('Kunde inte ladda konversation'));
          expect(
            newViewModel.isLoading,
            isFalse,
            reason:
                'setError lowers the loading flag — the assertion that '
                'separates "reported" from "still waiting". No message ever '
                'reaches the stream in this test, so nothing downstream can '
                'call setSuccess() and clear it for the wrong reason.',
          );

          // Clean up
          newViewModel.dispose();
        },
      );
    });

    group('Refresh and State Management', () {
      test('should handle refresh', () async {
        // Arrange & Act
        await viewModel.refresh();

        // Assert - refresh just waits, stream handles updates
        expect(viewModel.isLoading, isTrue); // Still loading initially
      });

      test('should check if can send messages', () {
        // Arrange - with conversation where current user is a participant
        final conversation = ConversationBuilder.build(
          id: testConversationId,
          participantIds: [testUserId, 'user2'],
          participantDisplayNames: {
            testUserId: 'Test User',
            'user2': 'Anna Andersson',
          },
        );
        final vmWithConversation = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: conversation,
        );

        // Act & Assert
        expect(vmWithConversation.canSendMessages, isTrue);

        // Clean up
        vmWithConversation.dispose();
      });

      test('should not send messages without conversation', () {
        // Arrange - create viewModel without initial conversation
        final vmWithoutConversation = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
        );

        // Act & Assert
        expect(vmWithoutConversation.canSendMessages, isFalse);

        // Clean up
        vmWithoutConversation.dispose();
      });

      test('should manually mark as read', () async {
        // Arrange & Act
        await viewModel.markAsRead();

        // Assert
        verify(
          () => mockMessagingService.markConversationAsRead(testConversationId),
        ).called(1);
      });
    });

    group('Lifecycle', () {
      test('should clean up on dispose', () {
        // Arrange
        final testConversation = ConversationBuilder.build(
          id: testConversationId,
          participantIds: [testUserId, 'user2'],
        );

        final testViewModel = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
          initialConversation: testConversation,
        );

        // Act & Assert - verify dispose doesn't throw
        expect(() => testViewModel.dispose(), returnsNormally);

        // Note: clearTypingIndicator is not called because ChatViewModel sets
        // _isDisposed = true before calling clearTyping(), which then returns early.
        // This appears to be a bug in the ChatViewModel implementation.
      });

      test('should cancel subscriptions on dispose', () async {
        // Arrange
        final testViewModel = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
        );

        // Act
        testViewModel.dispose();

        // Try to add messages after dispose
        messagesStreamController.add([MessageBuilder.build()]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - messages should not update after dispose
        expect(testViewModel.messages, isEmpty);
      });

      test('should not notify after dispose', () {
        // Arrange
        final testViewModel = ChatViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          messagingService: mockMessagingService,
          conversationId: testConversationId,
        );
        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        // Act
        testViewModel.dispose();
        // StateNotifierMixin.dispose() calls clearState() which may fire one
        // notification to reset loading/error state. After that, manual calls
        // like clearError should NOT notify because _isDisposed is true.
        final countAfterDispose = notificationCount;
        testViewModel.clearError(); // Try to trigger notification after dispose

        // Assert - no additional notifications after dispose
        expect(notificationCount, equals(countAfterDispose));
      });
    });
  });
}
