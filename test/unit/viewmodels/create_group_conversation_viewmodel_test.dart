// test/unit/viewmodels/create_group_conversation_viewmodel_test.dart
//
// GRP-06 — CreateGroupConversationViewModel
//
// Coverage intent per test:
//  1. participant selection/deselection via toggleMemberSelection
//  2. group-name validation guard (canCreateGroup invariant)
//  3. member-count validation guard (minimum 2 members)
//  4. create-group submit path — success: returns conversationId, no error
//  5. create-group submit path — failure: returns null, sets error, clears isCreatingGroup
//  6. create-group blocked when validation fails (empty name or < 2 members)
//  7. loading/isCreatingGroup state transitions during successful creation
//  8. loadFriends populates availableFriends from UnifiedFriendsService
//  9. BUT-1838 — ChatGroupRepository.createGroup wiring, incl. blocked-member
//     and rate-limit error mapping

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/create_group_conversation_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/service_mocks.dart'
    show MockChatGroupRepository;

// ---------------------------------------------------------------------------
// Local pure-Mock classes — no concrete @override bodies so when() works.
// ---------------------------------------------------------------------------
class _MockFriendsService extends Mock implements UnifiedFriendsService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  avatarUrl: null,
  isOnline: false,
  joinedAt: DateTime(2024),
  lastActiveAt: DateTime(2024),
);

final _friend1 = _profile('uid-anna', 'Anna Andersson');
final _friend2 = _profile('uid-erik', 'Erik Eriksson');
final _friend3 = _profile('uid-maria', 'Maria Nilsson');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late CreateGroupConversationViewModel viewModel;
  late MockChatGroupRepository mockChatGroupRepository;
  late _MockFriendsService mockFriends;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockChatGroupRepository = MockChatGroupRepository();
    mockFriends = _MockFriendsService();

    // Default: friends list has three members.
    when(() => mockFriends.friends).thenReturn([_friend1, _friend2, _friend3]);

    viewModel = CreateGroupConversationViewModel(
      friendsService: mockFriends,
      chatGroupRepository: mockChatGroupRepository,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  // -------------------------------------------------------------------------
  group('Participant selection', () {
    // Intent: selecting and deselecting a friend is reflected in selectedMemberIds
    // and the count getter. A refactor of the UI or internal data structure
    // must not change this user-visible toggle contract.
    test('toggleMemberSelection adds then removes a participant', () {
      expect(viewModel.selectedMemberCount, 0);
      expect(viewModel.isMemberSelected(_friend1.uid), isFalse);

      viewModel.toggleMemberSelection(_friend1.uid);

      expect(viewModel.selectedMemberCount, 1);
      expect(viewModel.isMemberSelected(_friend1.uid), isTrue);

      viewModel.toggleMemberSelection(_friend1.uid); // remove

      expect(viewModel.selectedMemberCount, 0);
      expect(viewModel.isMemberSelected(_friend1.uid), isFalse);
    });

    test('clearSelection removes all selected participants', () {
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);
      expect(viewModel.selectedMemberCount, 2);

      viewModel.clearSelection();

      expect(viewModel.selectedMemberCount, 0);
      expect(viewModel.hasSelectedMembers, isFalse);
    });

    test('selectedMembers maps IDs back to UserProfile objects', () async {
      await viewModel.loadFriends();
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend3.uid);

      final members = viewModel.selectedMembers;
      expect(members.length, 2);
      expect(
        members.map((m) => m.uid),
        containsAll([_friend1.uid, _friend3.uid]),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Group-name validation', () {
    // Intent: canCreateGroup is false when the name is blank, regardless of
    // how many members are selected. A blank-name group creation must never
    // reach the service layer.
    test('canCreateGroup is false when group name is empty', () {
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      // Name is still '' by default — cannot create yet.
      expect(viewModel.canCreateGroup, isFalse);
      expect(viewModel.validationError, isNotNull);
    });

    test('canCreateGroup is false when name is only whitespace', () {
      viewModel.updateGroupName('   ');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      expect(viewModel.canCreateGroup, isFalse);
    });

    test('canCreateGroup becomes true once name and >=2 members are set', () {
      viewModel.updateGroupName('Lördagsmat');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      expect(viewModel.canCreateGroup, isTrue);
      expect(viewModel.validationError, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('Member-count validation', () {
    // Intent: the ViewModel must enforce a minimum of 2 members before
    // allowing group creation. One-member groups must never reach the service.
    test('canCreateGroup is false with fewer than 2 members selected', () {
      viewModel.updateGroupName('Min grupp');
      viewModel.toggleMemberSelection(_friend1.uid); // only 1

      expect(viewModel.canCreateGroup, isFalse);
      expect(viewModel.validationError, isNotNull);
    });

    test('canCreateGroup is false with zero members selected', () {
      viewModel.updateGroupName('Min grupp');

      expect(viewModel.canCreateGroup, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('createGroupConversation — success path', () {
    // Intent: when validation passes and the repository succeeds, the VM
    // returns the group/conversation id and ends in a clean (no-error,
    // no-loading) state. The callable adds the caller automatically, so the
    // client only sends the OTHER selected members.
    test(
      'returns conversationId and clears isCreatingGroup on success',
      () async {
        when(
          () => mockChatGroupRepository.createGroup(
            name: any(named: 'name'),
            memberIds: any(named: 'memberIds'),
          ),
        ).thenAnswer((_) async => 'conv-new-group');

        await viewModel.loadFriends();
        viewModel.updateGroupName('Fredagsmat');
        viewModel.toggleMemberSelection(_friend1.uid);
        viewModel.toggleMemberSelection(_friend2.uid);

        final result = await viewModel.createGroupConversation();

        expect(result, equals('conv-new-group'));
        expect(viewModel.isCreatingGroup, isFalse);
        expect(viewModel.hasError, isFalse);
      },
    );

    test(
      'passes the trimmed name and selected member ids to the repository',
      () async {
        when(
          () => mockChatGroupRepository.createGroup(
            name: any(named: 'name'),
            memberIds: any(named: 'memberIds'),
          ),
        ).thenAnswer((_) async => 'conv-abc');

        await viewModel.loadFriends();
        viewModel.updateGroupName('  Köttbullsälskare  '); // trims whitespace
        viewModel.toggleMemberSelection(_friend1.uid);
        viewModel.toggleMemberSelection(_friend2.uid);

        await viewModel.createGroupConversation();

        final captured = verify(
          () => mockChatGroupRepository.createGroup(
            name: captureAny(named: 'name'),
            memberIds: captureAny(named: 'memberIds'),
          ),
        ).captured;

        expect(captured[0], equals('Köttbullsälskare'));
        final memberIds = captured[1] as List<String>;
        expect(memberIds, containsAll([_friend1.uid, _friend2.uid]));
      },
    );

    test('isCreatingGroup transitions true → false during creation', () async {
      when(
        () => mockChatGroupRepository.createGroup(
          name: any(named: 'name'),
          memberIds: any(named: 'memberIds'),
        ),
      ).thenAnswer((_) async => 'conv-xyz');

      await viewModel.loadFriends();
      viewModel.updateGroupName('Min grupp');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      var wasCreating = false;
      viewModel.addListener(() {
        if (viewModel.isCreatingGroup) wasCreating = true;
      });

      await viewModel.createGroupConversation();

      expect(
        wasCreating,
        isTrue,
        reason: 'isCreatingGroup must be true at least once during creation',
      );
      expect(viewModel.isCreatingGroup, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('createGroupConversation — failure path', () {
    // Intent: when the repository throws, the VM returns null, sets an error
    // state visible to the UI, and leaves isCreatingGroup=false.
    test('returns null and sets a generic error on unknown failure', () async {
      when(
        () => mockChatGroupRepository.createGroup(
          name: any(named: 'name'),
          memberIds: any(named: 'memberIds'),
        ),
      ).thenThrow(Exception('Network error'));

      await viewModel.loadFriends();
      viewModel.updateGroupName('Testgrupp');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      final result = await viewModel.createGroupConversation();

      expect(result, isNull);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, contains('Det gick inte att skapa gruppen'));
      expect(viewModel.isCreatingGroup, isFalse);
    });

    test(
      'surfaces blocked members without saying why (minor gate)',
      () async {
        when(
          () => mockChatGroupRepository.createGroup(
            name: any(named: 'name'),
            memberIds: any(named: 'memberIds'),
          ),
        ).thenThrow(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Some people could not be added to this group.',
            details: {
              'blockedUserIds': [_friend1.uid],
            },
          ),
        );

        await viewModel.loadFriends();
        viewModel.updateGroupName('Testgrupp');
        viewModel.toggleMemberSelection(_friend1.uid);
        viewModel.toggleMemberSelection(_friend2.uid);

        final result = await viewModel.createGroupConversation();

        expect(result, isNull);
        expect(viewModel.error, contains('kunde inte läggas till'));
        expect(viewModel.error, isNot(contains('minderårig')));
      },
    );

    test('surfaces rate-limit wording on resource-exhausted', () async {
      when(
        () => mockChatGroupRepository.createGroup(
          name: any(named: 'name'),
          memberIds: any(named: 'memberIds'),
        ),
      ).thenThrow(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
          details: const {'retryAfterSeconds': 45},
        ),
      );

      await viewModel.loadFriends();
      viewModel.updateGroupName('Testgrupp');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      final result = await viewModel.createGroupConversation();

      expect(result, isNull);
      expect(viewModel.error, contains('45'));
    });

    test(
      'surfaces the member-cap wording on invalid-argument',
      () async {
        when(
          () => mockChatGroupRepository.createGroup(
            name: any(named: 'name'),
            memberIds: any(named: 'memberIds'),
          ),
        ).thenThrow(
          FirebaseFunctionsException(
            code: 'invalid-argument',
            message: 'A group can hold at most 100 members.',
          ),
        );

        await viewModel.loadFriends();
        viewModel.updateGroupName('Testgrupp');
        viewModel.toggleMemberSelection(_friend1.uid);
        viewModel.toggleMemberSelection(_friend2.uid);

        final result = await viewModel.createGroupConversation();

        expect(result, isNull);
        expect(viewModel.error, contains('100'));
      },
    );

    test(
      'returns null immediately when validation fails (no service call)',
      () async {
        // Only one member selected — validation must block.
        viewModel.updateGroupName('Liten grupp');
        viewModel.toggleMemberSelection(_friend1.uid); // only 1

        final result = await viewModel.createGroupConversation();

        expect(result, isNull);
        verifyNever(
          () => mockChatGroupRepository.createGroup(
            name: any(named: 'name'),
            memberIds: any(named: 'memberIds'),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('loadFriends', () {
    // Intent: loadFriends must populate availableFriends from the service
    // so the UI can display the selection list.
    test('populates availableFriends from UnifiedFriendsService', () async {
      expect(viewModel.availableFriends, isEmpty);

      await viewModel.loadFriends();

      expect(viewModel.availableFriends.length, 3);
      expect(
        viewModel.availableFriends.map((f) => f.uid),
        containsAll([_friend1.uid, _friend2.uid, _friend3.uid]),
      );
    });

    test('availableFriends is empty when service returns empty list', () async {
      when(() => mockFriends.friends).thenReturn([]);

      await viewModel.loadFriends();

      expect(viewModel.availableFriends, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('searchFriends', () {
    // Intent: searchFriends filters by display name; an empty query returns all.
    test('returns all friends when query is empty', () async {
      await viewModel.loadFriends();
      expect(viewModel.searchFriends('').length, 3);
    });

    test('filters by display name case-insensitively', () async {
      await viewModel.loadFriends();
      final results = viewModel.searchFriends('anna');
      expect(results.length, 1);
      expect(results.first.uid, equals(_friend1.uid));
    });
  });
}
