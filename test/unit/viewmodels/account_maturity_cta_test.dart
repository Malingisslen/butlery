/// BUT-1417: Maturity gate wired into social CTAs.
///
/// Verifies that friend requests, DM sends, and group invites are blocked
/// (returning false, setting an error, NOT calling the downstream service)
/// when AccountMaturityHelper.isMatured() returns false, and proceed normally
/// when it returns true.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';

// ---------------------------------------------------------------------------
// Local mocks
// ---------------------------------------------------------------------------

class _MockUser extends Mock implements User {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockManagement extends Mock implements FriendsManagementOperations {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

class _MockInvitations extends Mock implements FriendsInvitationsOperations {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// An AccountMaturityHelper that always returns [result].
AccountMaturityHelper _fixedHelper(bool result) => AccountMaturityHelper(
  // Use a window of 60 min but a fixed `now` that puts us either well within
  // or well outside the window based on [result].
  window: const Duration(minutes: 60),
  now: result
      ? () =>
            DateTime.utc(2026, 1, 1, 2, 0) // 2h after joinedAt → matured
      : () => DateTime.utc(2026, 1, 1, 0, 30), // 30 min after → not matured
);

UserProfile _profile({DateTime? joinedAt}) => UserProfile(
  uid: 'test-user',
  displayName: 'Anna',
  email: 'anna@example.com',
  joinedAt: joinedAt ?? DateTime.utc(2026, 1, 1, 0, 0),
  lastActiveAt: DateTime.utc(2026, 1, 1, 0, 0),
);

AuthRepository _authRepoWithNoUser() {
  final repo = _MockAuthRepository();
  when(() => repo.currentUser).thenReturn(null);
  return repo;
}

// ---------------------------------------------------------------------------
// Tests: FriendsViewModel.sendFriendRequest
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  // =========================================================================
  // FriendsViewModel — friend request gate
  // =========================================================================
  group('FriendsViewModel.sendFriendRequest — maturity gate', () {
    late _MockFriendsService friendsService;
    late _MockManagement management;
    late _MockCategories categories;
    late MockUserService userService;
    late MockAnalyticsService analyticsService;
    late FakePermissionService permissionService;

    setUp(() async {
      await TestServiceLocator.initialize();

      friendsService = _MockFriendsService();
      management = _MockManagement();
      categories = _MockCategories();
      userService = MockUserService();
      analyticsService = MockAnalyticsService();
      permissionService = FakePermissionService();

      when(
        () => friendsService.stateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => friendsService.management).thenReturn(management);
      when(() => friendsService.categories).thenReturn(categories);
      when(() => friendsService.friends).thenReturn([]);
      when(() => friendsService.incomingRequests).thenReturn([]);
      when(() => friendsService.outgoingRequests).thenReturn([]);
      when(() => friendsService.isLoading).thenReturn(false);
      when(() => friendsService.hasError).thenReturn(false);
      when(() => friendsService.error).thenReturn(null);
      when(() => friendsService.categoriesList).thenReturn([]);
      when(() => management.getAllFriends()).thenReturn([]);
      when(() => management.getIncomingRequests()).thenReturn([]);
      when(() => management.getOutgoingRequests()).thenReturn([]);
      when(() => categories.getCategoryById(any())).thenReturn(null);

      // Stub currentUserProfile so isMatured can inspect joinedAt
      when(() => userService.currentUserProfile).thenReturn(_profile());
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'blocks request and sets error when account is NOT matured',
      () async {
        // Arrange — helper will return false (30 min old, unverified)
        final vm = FriendsViewModel(
          friendsService: friendsService,
          userService: userService,
          analyticsService: analyticsService,
          permissionService: permissionService,
          maturityHelper: _fixedHelper(false),
          authRepository: _authRepoWithNoUser(),
        );

        // Act
        final result = await vm.sendFriendRequest('target-user');

        // Assert: CTA blocked
        expect(
          result,
          isFalse,
          reason: 'sendFriendRequest must return false for unmatured accounts',
        );
        expect(
          vm.error,
          isNotNull,
          reason: 'error must be set so the view can surface the message',
        );
        expect(
          vm.hasError,
          isTrue,
          reason:
              'hasError must agree with error (BUT-1417) — a view guarding on '
              'hasError before rendering the banner must see the maturity error',
        );
        // Assert: downstream service NOT called
        verifyNever(
          () => management.sendFriendRequest(
            any(),
            message: any(named: 'message'),
          ),
        );

        vm.dispose();
      },
    );

    test(
      'proceeds normally when account IS matured (email verified)',
      () async {
        // Arrange — helper returns true (2h old)
        final mockUser = _MockUser();
        when(() => mockUser.emailVerified).thenReturn(true);
        final authRepo = _MockAuthRepository();
        when(() => authRepo.currentUser).thenReturn(mockUser);

        when(
          () => management.sendFriendRequest(
            any(),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async => true);

        final vm = FriendsViewModel(
          friendsService: friendsService,
          userService: userService,
          analyticsService: analyticsService,
          permissionService: permissionService,
          maturityHelper: _fixedHelper(true),
          authRepository: authRepo,
        );

        // Act
        final result = await vm.sendFriendRequest('target-user');

        // Assert: CTA proceeds
        expect(
          result,
          isTrue,
          reason: 'sendFriendRequest must succeed for matured accounts',
        );
        verify(
          () => management.sendFriendRequest(
            'target-user',
            message: any(named: 'message'),
          ),
        ).called(1);

        vm.dispose();
      },
    );
  });

  // =========================================================================
  // ChatViewModel — send message gate
  // =========================================================================
  group('ChatViewModel.sendTextMessage — maturity gate', () {
    late MockMessagingService messagingService;
    // ignore: close_sinks
    late StreamController<List<Message>> messagesController;
    const convId = 'conv-test';

    Conversation conv() => Conversation(
      id: convId,
      participantIds: ['test-user', 'other-user'],
      participantDisplayNames: {
        'test-user': 'Anna',
        'other-user': 'Erik',
      },
      participantAvatarUrls: {},
      isGroup: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lastReadTimestamps: {},
      metadata: {},
    );

    setUp(() async {
      await TestServiceLocator.initialize();

      messagingService = MockMessagingService();
      messagesController = StreamController<List<Message>>.broadcast();

      when(
        () => messagingService.getConversationMessages(
          conversationId: any(named: 'conversationId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => messagesController.stream);

      when(
        () => messagingService.sendTextMessage(
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          replyToMessageId: any(named: 'replyToMessageId'),
        ),
      ).thenAnswer(
        (_) async => Message(
          id: 'msg1',
          conversationId: convId,
          senderId: 'test-user',
          senderDisplayName: 'Anna',
          senderAvatarUrl: null,
          type: MessageType.text,
          content: 'hello',
          status: MessageStatus.delivered,
          sentAt: DateTime.utc(2026, 1, 1),
          metadata: null,
          isEdited: false,
        ),
      );

      when(
        () => messagingService.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      messagesController.close();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'sets sendError and returns false when account is NOT matured',
      () async {
        final userService = MockUserService();
        when(() => userService.currentUserProfile).thenReturn(_profile());

        final vm = ChatViewModel(
          messagingService: messagingService,
          conversationId: convId,
          initialConversation: conv(),
          maturityHelper: _fixedHelper(false),
          userService: userService,
          authRepository: _authRepoWithNoUser(),
        );

        final result = await vm.sendTextMessage('hej');

        expect(
          result,
          isFalse,
          reason: 'sendTextMessage must return false for unmatured accounts',
        );
        expect(
          vm.sendError,
          isNotNull,
          reason: 'sendError must be set so the chat input can show guidance',
        );
        // Downstream service must NOT have been called
        verifyNever(
          () => messagingService.sendTextMessage(
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        );

        vm.dispose();
      },
    );

    test(
      'calls messaging service when account IS matured',
      () async {
        final userService = MockUserService();
        when(() => userService.currentUserProfile).thenReturn(_profile());

        final vm = ChatViewModel(
          messagingService: messagingService,
          conversationId: convId,
          initialConversation: conv(),
          maturityHelper: _fixedHelper(true),
          userService: userService,
          authRepository: _authRepoWithNoUser(),
        );

        final result = await vm.sendTextMessage('hej');

        expect(
          result,
          isTrue,
          reason: 'sendTextMessage must succeed for matured accounts',
        );
        verify(
          () => messagingService.sendTextMessage(
            conversationId: convId,
            content: 'hej',
            replyToMessageId: any(named: 'replyToMessageId'),
          ),
        ).called(1);

        vm.dispose();
      },
    );
  });

  // =========================================================================
  // AddMembersToGroupViewModel — group invite gate
  // =========================================================================
  group('AddMembersToGroupViewModel.sendInvitations — maturity gate', () {
    late _MockFriendsService friendsService;
    late _MockManagement management;
    late _MockCategories categories;
    late _MockInvitations invitations;
    const groupId = 'group-123';

    FriendCategory testGroup() => FriendCategory(
      id: groupId,
      ownerId: 'test-user',
      name: 'Matlagningsgruppen',
      description: '',
      emoji: '🍴',
      friendUserIds: [],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      sortOrder: 0,
      isDefault: false,
    );

    UserProfile friend(String uid, String name) => UserProfile(
      uid: uid,
      displayName: name,
      email: '$uid@test.com',
      joinedAt: DateTime.utc(2026, 1, 1),
      lastActiveAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() async {
      await TestServiceLocator.initialize();

      friendsService = _MockFriendsService();
      management = _MockManagement();
      categories = _MockCategories();
      invitations = _MockInvitations();

      when(() => friendsService.management).thenReturn(management);
      when(() => friendsService.categories).thenReturn(categories);
      when(() => friendsService.invitations).thenReturn(invitations);
      when(() => friendsService.currentUserId).thenReturn('test-user');
      when(() => friendsService.hasError).thenReturn(false);
      when(() => friendsService.error).thenReturn(null);
      when(() => friendsService.refresh()).thenAnswer((_) async {});

      when(() => categories.getCategoryById(groupId)).thenReturn(testGroup());
      when(() => management.getAllFriends()).thenReturn([
        friend('friend-1', 'Anna Andersson'),
        friend('friend-2', 'Erik Eriksson'),
      ]);
      when(() => invitations.getSentInvitations()).thenReturn([]);
      when(
        () => invitations.sendGroupInvitationToUser(
          userId: any(named: 'userId'),
          groupId: any(named: 'groupId'),
          customMessage: any(named: 'customMessage'),
        ),
      ).thenAnswer((_) async => true);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'sets invitationError and returns false when account is NOT matured',
      () async {
        final userService = MockUserService();
        when(() => userService.currentUserProfile).thenReturn(_profile());

        final vm = AddMembersToGroupViewModel(
          groupId: groupId,
          friendsService: friendsService,
          maturityHelper: _fixedHelper(false),
          userService: userService,
          authRepository: _authRepoWithNoUser(),
        );
        await pumpEventQueue(); // let _initializeData run

        // Select a friend to satisfy canSendInvitations
        vm.toggleFriendSelection('friend-1');

        final result = await vm.sendInvitations();

        expect(
          result,
          isFalse,
          reason: 'sendInvitations must return false for unmatured accounts',
        );
        expect(
          vm.invitationError,
          isNotNull,
          reason: 'invitationError must be set for the view to show guidance',
        );
        // Downstream service NOT called
        verifyNever(
          () => invitations.sendGroupInvitationToUser(
            userId: any(named: 'userId'),
            groupId: any(named: 'groupId'),
            customMessage: any(named: 'customMessage'),
          ),
        );

        vm.dispose();
      },
    );

    test(
      'sends invitations when account IS matured',
      () async {
        final userService = MockUserService();
        when(() => userService.currentUserProfile).thenReturn(_profile());

        final vm = AddMembersToGroupViewModel(
          groupId: groupId,
          friendsService: friendsService,
          maturityHelper: _fixedHelper(true),
          userService: userService,
          authRepository: _authRepoWithNoUser(),
        );
        await pumpEventQueue();

        vm.toggleFriendSelection('friend-1');

        final result = await vm.sendInvitations();

        expect(
          result,
          isTrue,
          reason: 'sendInvitations must succeed for matured accounts',
        );
        verify(
          () => invitations.sendGroupInvitationToUser(
            userId: 'friend-1',
            groupId: groupId,
            customMessage: any(named: 'customMessage'),
          ),
        ).called(1);

        vm.dispose();
      },
    );
  });
}
