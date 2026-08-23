import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/messaging_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';

class MockFriendCategoryRepository extends Mock
    implements FriendCategoryRepository {}

void main() {
  group('SocialGroupDetailViewModel', () {
    late SocialGroupDetailViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late FakePermissionService mockPermissionService;
    late MockFriendsCategoriesOperations mockCategoriesOps;
    late MockFriendCategoryRepository mockCategoryRepo;

    const testGroupId = 'test_group_123';
    const testUserId = 'test_user_123';
    const otherUserId = 'other_user_456';
    final now = DateTime(2026, 4, 14);

    final testGroup = FriendCategory(
      id: testGroupId,
      name: 'Test Social Group',
      description: 'A test group',
      emoji: 'party',
      ownerId: testUserId,
      friendUserIds: [testUserId, otherUserId],
      createdAt: now,
      updatedAt: now,
    );

    final currentUser = UserProfile(
      uid: testUserId,
      displayName: 'Test Owner',
      email: 'owner@example.com',
      joinedAt: now,
      lastActiveAt: now,
    );

    final otherMember = UserProfile(
      uid: otherUserId,
      displayName: 'Other Member',
      email: 'member@example.com',
      joinedAt: now,
      lastActiveAt: now,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(
        FriendCategory(
          id: 'fb',
          ownerId: 'fb',
          name: 'fb',
          createdAt: now,
          updatedAt: now,
        ),
      );
      registerFallbackValue(currentUser);
    });

    setUp(() {
      mockFriendsService = MockUnifiedFriendsService();
      mockUserService = MockUserService();
      mockPermissionService = FakePermissionService();
      mockCategoriesOps = MockFriendsCategoriesOperations();
      mockCategoryRepo = MockFriendCategoryRepository();

      // Wire categories ops through setFriendsState (concrete override)
      mockFriendsService.setFriendsState(
        categories: mockCategoriesOps,
      );

      // Stubs on mock (not concrete overrides -- safe to use when())
      when(() => mockFriendsService.refresh()).thenAnswer((_) async {});
      when(
        () => mockFriendsService.getCategoryById(testGroupId),
      ).thenReturn(testGroup);
      when(() => mockFriendsService.sentInvitations).thenReturn([]);
      when(
        () => mockFriendsService.friendsCategoryRepositoryInternal,
      ).thenReturn(mockCategoryRepo);

      // MockUserService.getUserProfiles is a concrete override using _users map
      mockUserService.setUserState(
        users: {
          testUserId: currentUser,
          otherUserId: otherMember,
        },
      );

      // FakePermissionService uses setPermissionState
      mockPermissionService.setPermissionState(
        currentUserId: testUserId,
        isAuthenticated: true,
      );

      // isGroupAdmin is now a concrete override on FakePermissionService;
      // use the dedicated setter (Fake doesn't support mocktail when()).
      // Default is `true` for all groups, matching the prior stub intent.
      mockPermissionService.setGroupAdmin(isAdmin: true);

      when(
        () => mockCategoriesOps.removeFriendFromCategory(any(), any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockCategoryRepo.transferOwnership(any(), any(), any()),
      ).thenAnswer((_) async {});

      viewModel = SocialGroupDetailViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
        userService: mockUserService,
        permissionService: mockPermissionService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('loads group data on initialization', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.group, isNotNull);
        expect(viewModel.group?.id, equals(testGroupId));
        expect(viewModel.group?.name, equals('Test Social Group'));
      });

      test('loads member profiles', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.members, hasLength(2));
        expect(
          viewModel.members.map((m) => m.uid),
          containsAll([testUserId, otherUserId]),
        );
      });
    });

    group('Permission Getters', () {
      test('isAdmin returns true when user is group admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.isAdmin, isTrue);
      });

      test('isAdmin returns false when user is not admin', () async {
        mockPermissionService.setGroupAdmin(
          groupId: testGroupId,
          isAdmin: false,
        );

        await viewModel.loadGroupData();

        expect(viewModel.isAdmin, isFalse);
      });

      test('canEditGroup returns true when user is admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canEditGroup, isTrue);
      });

      test('canDeleteGroup returns true when user is admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canDeleteGroup, isTrue);
      });

      test('canLeaveGroup returns true when user is a member', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canLeaveGroup, isTrue);
      });
    });

    group('loadGroupData', () {
      test('loads group and member data successfully', () async {
        await viewModel.loadGroupData();

        expect(viewModel.group, isNotNull);
        expect(viewModel.members, hasLength(2));
        expect(viewModel.isLoading, isFalse);
      });

      test('handles null group gracefully', () async {
        when(
          () => mockFriendsService.getCategoryById(testGroupId),
        ).thenReturn(null);

        await viewModel.loadGroupData();

        expect(viewModel.group, isNull);
        expect(viewModel.members, isEmpty);
      });
    });

    group('refreshData', () {
      test('refreshes all data', () async {
        await viewModel.refreshData();

        verify(() => mockFriendsService.refresh()).called(greaterThan(0));
        expect(viewModel.group, isNotNull);
      });
    });

    group('checkLeaveGroupRequirements', () {
      test('returns no transfer needed for non-owner', () async {
        mockPermissionService.setGroupAdmin(
          groupId: testGroupId,
          isAdmin: false,
        );

        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isFalse);
        expect(decision.groupIsEmpty, isFalse);
        expect(decision.availableNewOwners, isEmpty);
      });

      test('returns empty group for owner with no other members', () async {
        final emptyGroup = testGroup.copyWith(friendUserIds: [testUserId]);
        when(
          () => mockFriendsService.getCategoryById(testGroupId),
        ).thenReturn(emptyGroup);

        // getUserProfiles will return only currentUser based on _users map
        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isFalse);
        expect(decision.groupIsEmpty, isTrue);
        expect(decision.availableNewOwners, isEmpty);
      });

      test('returns transfer required for owner with other members', () async {
        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isTrue);
        expect(decision.groupIsEmpty, isFalse);
        expect(decision.availableNewOwners, hasLength(1));
        expect(decision.availableNewOwners.first.uid, equals(otherUserId));
      });
    });

    group('leaveGroup', () {
      test('successfully leaves group', () async {
        when(
          () => mockCategoriesOps.removeFriendFromCategory(
            testUserId,
            testGroupId,
          ),
        ).thenAnswer((_) async => true);

        await viewModel.loadGroupData();
        final result = await viewModel.leaveGroup();

        expect(result, isTrue);
        expect(viewModel.group, isNull);
        verify(
          () => mockCategoriesOps.removeFriendFromCategory(
            testUserId,
            testGroupId,
          ),
        ).called(1);
      });

      test('returns false when leave fails', () async {
        when(
          () => mockCategoriesOps.removeFriendFromCategory(
            testUserId,
            testGroupId,
          ),
        ).thenAnswer((_) async => false);

        await viewModel.loadGroupData();
        final result = await viewModel.leaveGroup();

        expect(result, isFalse);
      });

      test('throws StateError when group is null', () async {
        when(
          () => mockFriendsService.getCategoryById(testGroupId),
        ).thenReturn(null);

        await viewModel.loadGroupData();

        expect(
          () => viewModel.leaveGroup(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('transferGroupOwnership', () {
      test('successfully transfers ownership', () async {
        await viewModel.loadGroupData();
        final result = await viewModel.transferGroupOwnership(otherMember);

        expect(result, isTrue);
        verify(
          () => mockCategoryRepo.transferOwnership(
            testUserId,
            testGroupId,
            otherUserId,
          ),
        ).called(1);
      });

      test('returns false when transfer fails', () async {
        when(
          () => mockCategoryRepo.transferOwnership(any(), any(), any()),
        ).thenThrow(Exception('Transfer failed'));

        await viewModel.loadGroupData();
        final result = await viewModel.transferGroupOwnership(otherMember);

        expect(result, isFalse);
      });

      test('throws StateError when group is null', () async {
        when(
          () => mockFriendsService.getCategoryById(testGroupId),
        ).thenReturn(null);

        await viewModel.loadGroupData();

        expect(
          () => viewModel.transferGroupOwnership(otherMember),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Content Sharing Coordination', () {
      test('canShareRecipeWithGroup returns true when authenticated', () async {
        await viewModel.loadGroupData();

        expect(viewModel.canShareRecipeWithGroup(), isTrue);
      });

      test('canShareMenuWithGroup returns true when authenticated', () async {
        await viewModel.loadGroupData();

        expect(viewModel.canShareMenuWithGroup(), isTrue);
      });

      test(
        'canShareShoppingListWithGroup returns true when authenticated',
        () async {
          await viewModel.loadGroupData();

          expect(viewModel.canShareShoppingListWithGroup(), isTrue);
        },
      );

      test('sharing methods return false when not authenticated', () async {
        mockPermissionService.setPermissionState(isAuthenticated: false);

        final unAuthViewModel = SocialGroupDetailViewModel(
          groupId: testGroupId,
          friendsService: mockFriendsService,
          userService: mockUserService,
          permissionService: mockPermissionService,
        );

        await unAuthViewModel.loadGroupData();

        expect(unAuthViewModel.canShareRecipeWithGroup(), isFalse);
        expect(unAuthViewModel.canShareMenuWithGroup(), isFalse);
        expect(unAuthViewModel.canShareShoppingListWithGroup(), isFalse);

        unAuthViewModel.dispose();
      });
    });

    /// BUT-1856: the meal-vote poll reuses ONE chat per social group instead of
    /// minting a new, undeletable one per vote.
    ///
    /// The ViewModel resolves `MessagingService` through the production
    /// `ServiceLocator` INSIDE the method, so these tests stand one up and
    /// register a mock in GetIt — the rest of the file does not need it, hence
    /// the group-local setUp rather than a change to the file's setUpAll.
    group('startMealVotePoll (BUT-1856)', () {
      late MockMessagingService mockMessaging;
      final recipes = [
        RecipeFactory.build(id: 'r1', title: 'Pannkakor'),
        RecipeFactory.build(id: 'r2', title: 'Lasagne'),
      ];

      setUp(() {
        ServiceLocator.initialize(DIContainer());
        mockMessaging = MockMessagingService();
        final getIt = GetIt.instance;
        if (getIt.isRegistered<MessagingService>()) {
          getIt.unregister<MessagingService>();
        }
        getIt.registerSingleton<MessagingService>(mockMessaging);

        when(
          () => mockMessaging.ensureCategoryChat(
            ownerId: any(named: 'ownerId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => 'conv-1');
        when(
          () => mockMessaging.sendPollMessage(
            conversationId: any(named: 'conversationId'),
            pollData: any(named: 'pollData'),
          ),
        ).thenAnswer((_) async {});
      });

      tearDown(() {
        final getIt = GetIt.instance;
        if (getIt.isRegistered<MessagingService>()) {
          getIt.unregister<MessagingService>();
        }
      });

      test('every poll asks for the chat and posts into the answer', () async {
        await viewModel.loadGroupData();

        final first = await viewModel.startMealVotePoll(
          question: 'Vad ska vi äta?',
          recipes: recipes,
        );
        final second = await viewModel.startMealVotePoll(
          question: 'Och på fredag?',
          recipes: recipes,
        );

        expect(first, equals('conv-1'));
        expect(second, equals(first));
        // The reuse decision is the callable's; what this pins is that the VM
        // asks the SAME question both times and posts into whatever it gets
        // back, rather than opening a new conversation itself.
        verify(
          () => mockMessaging.ensureCategoryChat(
            ownerId: testUserId,
            categoryId: testGroupId,
          ),
        ).called(2);
        verify(
          () => mockMessaging.sendPollMessage(
            conversationId: 'conv-1',
            pollData: any(named: 'pollData'),
          ),
        ).called(2);
      });

      test('never opens a group conversation directly any more', () async {
        await viewModel.loadGroupData();

        await viewModel.startMealVotePoll(
          question: 'Vad ska vi äta?',
          recipes: recipes,
        );

        // The old path (`createGroupConversation`) is what minted a chat per
        // poll. It still exists for the messaging screens; this flow must not
        // reach it.
        verifyNever(
          () => mockMessaging.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
          ),
        );
      });

      test(
        'a member profile that fails to load no longer shrinks the chat',
        () async {
          // The roster is resolved server-side now. Before BUT-1856 the VM built
          // the participant list from these profiles, so an unreadable one
          // quietly left that person out of the chat.
          mockUserService.setUserState(users: {});
          await viewModel.loadGroupData();

          final result = await viewModel.startMealVotePoll(
            question: 'Vad ska vi äta?',
            recipes: recipes,
          );

          expect(result, equals('conv-1'));
          expect(viewModel.members, isEmpty);
        },
      );

      test(
        'a one-person group returns null with the Swedish explanation',
        () async {
          when(
            () => mockMessaging.ensureCategoryChat(
              ownerId: any(named: 'ownerId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenThrow(
            FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'This group has no other members.',
              details: const {'reason': 'group-too-small'},
            ),
          );
          await viewModel.loadGroupData();

          final result = await viewModel.startMealVotePoll(
            question: 'Vad ska vi äta?',
            recipes: recipes,
          );

          // `executeAsync` sets the error AND rethrows, so without the catch in
          // startMealVotePoll this call THROWS and the view's null branch — the
          // only thing that shows a message — never runs.
          expect(result, isNull);
          expect(
            viewModel.errorMessage,
            equals(AppLocale.current.chatGroupNeedsAnotherMember),
          );
          verifyNever(
            () => mockMessaging.sendPollMessage(
              conversationId: any(named: 'conversationId'),
              pollData: any(named: 'pollData'),
            ),
          );
        },
      );

      test(
        'any other failure returns null with the generic poll message',
        () async {
          when(
            () => mockMessaging.ensureCategoryChat(
              ownerId: any(named: 'ownerId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenThrow(StateError('network down'));
          await viewModel.loadGroupData();

          final result = await viewModel.startMealVotePoll(
            question: 'Vad ska vi äta?',
            recipes: recipes,
          );

          expect(result, isNull);
          expect(
            viewModel.errorMessage,
            equals(AppLocale.current.mealVotePollFailed),
          );
        },
      );

      test('an unauthenticated caller never reaches the callable', () async {
        await viewModel.loadGroupData();
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );

        final result = await viewModel.startMealVotePoll(
          question: 'Vad ska vi äta?',
          recipes: recipes,
        );

        expect(result, isNull);
        verifyNever(
          () => mockMessaging.ensureCategoryChat(
            ownerId: any(named: 'ownerId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
        // The early returns sit ABOVE `executeAsync`, so its
        // clear-error-on-start never runs for them. The view reads
        // `errorMessage` for its snackbar now, so a message left over from an
        // earlier failed poll would be shown again for an unrelated refusal.
        expect(viewModel.errorMessage, isNull);
      });

      test(
        'the callable is asked for the OWNER, not the signed-in user',
        () async {
          // The two are the same uid in every other fixture, which makes a
          // `group.ownerId` -> `currentUserId` swap unkillable — and that swap
          // breaks the meal vote for every non-owner member, because the callable
          // addresses `users/{ownerId}/friend_categories/{categoryId}`.
          await viewModel.loadGroupData();
          mockPermissionService.setPermissionState(
            currentUserId: otherUserId,
            isAuthenticated: true,
          );

          await viewModel.startMealVotePoll(
            question: 'Vad ska vi äta?',
            recipes: recipes,
          );

          verify(
            () => mockMessaging.ensureCategoryChat(
              ownerId: testUserId,
              categoryId: testGroupId,
            ),
          ).called(1);
        },
      );

      test(
        'the poll itself carries the question, the recipes and the mode',
        () async {
          await viewModel.loadGroupData();

          await viewModel.startMealVotePoll(
            question: 'Vad ska vi äta på fredag?',
            recipes: recipes,
            allowMultipleChoices: true,
          );

          final captured =
              verify(
                    () => mockMessaging.sendPollMessage(
                      conversationId: 'conv-1',
                      pollData: captureAny(named: 'pollData'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;

          expect(captured['question'], equals('Vad ska vi äta på fredag?'));
          expect(captured['allowMultipleChoices'], isTrue);
          expect(captured['creatorId'], equals(testUserId));
          final options = captured['options'] as List;
          expect(
            options.map((o) => (o as Map)['text']),
            containsAll(['Pannkakor', 'Lasagne']),
          );
          expect(
            options.map((o) => (o as Map)['recipeId']),
            containsAll(['r1', 'r2']),
          );
        },
      );
    });
  });
}
