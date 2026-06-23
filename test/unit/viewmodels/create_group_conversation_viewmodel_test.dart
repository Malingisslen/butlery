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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/create_group_conversation_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// ---------------------------------------------------------------------------
// Local pure-Mock classes — no concrete @override bodies so when() works.
// ---------------------------------------------------------------------------
class _MockMessagingService extends Mock implements MessagingService {}

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
  late _MockMessagingService mockMessaging;
  late _MockFriendsService mockFriends;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockMessaging = _MockMessagingService();
    mockFriends = _MockFriendsService();

    // Default: friends list has three members.
    when(() => mockFriends.friends).thenReturn([_friend1, _friend2, _friend3]);

    viewModel = CreateGroupConversationViewModel(
      messagingService: mockMessaging,
      friendsService: mockFriends,
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
    // Intent: when validation passes and the service succeeds, the VM
    // returns the conversation ID and ends in a clean (no-error, no-loading) state.
    test(
      'returns conversationId and clears isCreatingGroup on success',
      () async {
        when(
          () => mockMessaging.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
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

    test('passes participant display names and title to the service', () async {
      when(
        () => mockMessaging.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        ),
      ).thenAnswer((_) async => 'conv-abc');

      await viewModel.loadFriends();
      viewModel.updateGroupName('  Köttbullsälskare  '); // trims whitespace
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      await viewModel.createGroupConversation();

      final captured = verify(
        () => mockMessaging.createGroupConversation(
          participantIds: captureAny(named: 'participantIds'),
          participantDisplayNames: captureAny(named: 'participantDisplayNames'),
          participantAvatarUrls: captureAny(named: 'participantAvatarUrls'),
          title: captureAny(named: 'title'),
        ),
      ).captured;

      // captured[0]=participantIds, [1]=displayNames, [2]=avatarUrls, [3]=title
      expect(captured[3], equals('Köttbullsälskare'));
      final displayNames = captured[1] as Map<String, String>;
      expect(displayNames[_friend1.uid], equals('Anna Andersson'));
      expect(displayNames[_friend2.uid], equals('Erik Eriksson'));
    });

    test('isCreatingGroup transitions true → false during creation', () async {
      when(
        () => mockMessaging.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
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
    // Intent: when the service throws, the VM returns null, sets an error
    // state visible to the UI, and leaves isCreatingGroup=false.
    test('returns null and sets error on service failure', () async {
      when(
        () => mockMessaging.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        ),
      ).thenThrow(Exception('Network error'));

      await viewModel.loadFriends();
      viewModel.updateGroupName('Testgrupp');
      viewModel.toggleMemberSelection(_friend1.uid);
      viewModel.toggleMemberSelection(_friend2.uid);

      final result = await viewModel.createGroupConversation();

      expect(result, isNull);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.isCreatingGroup, isFalse);
    });

    test(
      'returns null immediately when validation fails (no service call)',
      () async {
        // Only one member selected — validation must block.
        viewModel.updateGroupName('Liten grupp');
        viewModel.toggleMemberSelection(_friend1.uid); // only 1

        final result = await viewModel.createGroupConversation();

        expect(result, isNull);
        verifyNever(
          () => mockMessaging.createGroupConversation(
            participantIds: any(named: 'participantIds'),
            participantDisplayNames: any(named: 'participantDisplayNames'),
            participantAvatarUrls: any(named: 'participantAvatarUrls'),
            title: any(named: 'title'),
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
