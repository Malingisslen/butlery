import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _CountingUserService extends MockUserService {
  int profileReads = 0;
  Completer<void>? gate;

  @override
  Future<ProfileBatchLookup> getUserProfiles(List<String> userIds) async {
    profileReads++;
    final pending = gate;
    if (pending != null) await pending.future;
    return super.getUserProfiles(userIds);
  }
}

void main() {
  group('SocialGroupDetailViewModel.resolveLeaveGroupRequirements', () {
    const groupId = 'group_1';
    const ownerId = 'owner_1';
    const memberId = 'member_2';
    final now = DateTime(2026, 4, 14);

    final group = FriendCategory(
      id: groupId,
      name: 'Grupp',
      ownerId: ownerId,
      friendUserIds: [ownerId, memberId],
      createdAt: now,
      updatedAt: now,
    );
    UserProfile profile(String uid) => UserProfile(
      uid: uid,
      displayName: uid,
      email: '$uid@example.com',
      joinedAt: now,
      lastActiveAt: now,
    );

    late _CountingUserService userService;
    late MockUnifiedFriendsService friendsService;
    late FakePermissionService permissionService;
    late SocialGroupDetailViewModel viewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<void> createLoadedViewModel() async {
      userService = _CountingUserService()
        ..setUserState(
          users: {ownerId: profile(ownerId), memberId: profile(memberId)},
          unavailableIds: {memberId},
        );
      friendsService = MockUnifiedFriendsService();
      permissionService = FakePermissionService()
        ..setPermissionState(currentUserId: ownerId, isAuthenticated: true)
        ..setGroupAdmin(isAdmin: true);
      when(() => friendsService.refresh()).thenAnswer((_) async {});
      when(() => friendsService.getCategoryById(groupId)).thenReturn(group);
      when(() => friendsService.sentInvitations).thenReturn([]);

      viewModel = SocialGroupDetailViewModel(
        groupId: groupId,
        friendsService: friendsService,
        userService: userService,
        permissionService: permissionService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await viewModel.loadGroupData();
    }

    var disposedByTest = false;

    tearDown(() {
      if (!disposedByTest) viewModel.dispose();
      disposedByTest = false;
    });

    test('a refusal is followed by a real second profile read', () async {
      await createLoadedViewModel();
      final readsAfterLoad = userService.profileReads;

      final decision = await viewModel.resolveLeaveGroupRequirements();

      expect(userService.profileReads, readsAfterLoad + 1);
      expect(decision.rosterIncomplete, isTrue);
      expect(viewModel.isResolvingLeave, isFalse);
    });

    test('a re-read that resolves everyone lets the owner transfer', () async {
      await createLoadedViewModel();
      expect(viewModel.checkLeaveGroupRequirements().rosterIncomplete, isTrue);
      userService.setUserState(unavailableIds: const {});

      final decision = await viewModel.resolveLeaveGroupRequirements();

      expect(decision.rosterIncomplete, isFalse);
      expect(decision.requiresOwnershipTransfer, isTrue);
      expect(decision.availableNewOwners.map((m) => m.uid), [memberId]);
      expect(viewModel.hasUnresolvedMembers, isFalse);
    });

    test('a complete roster is not read again', () async {
      await createLoadedViewModel();
      userService.setUserState(unavailableIds: const {});
      await viewModel.loadGroupData();
      await viewModel.refreshData();
      final readsBefore = userService.profileReads;

      await viewModel.resolveLeaveGroupRequirements();

      expect(userService.profileReads, readsBefore);
    });

    test('a second call while resolving does not read again', () async {
      await createLoadedViewModel();
      final readsAfterLoad = userService.profileReads;
      userService.gate = Completer<void>();

      final first = viewModel.resolveLeaveGroupRequirements();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isResolvingLeave, isTrue);

      final second = await viewModel.resolveLeaveGroupRequirements();
      expect(second.rosterIncomplete, isTrue);
      expect(userService.profileReads, readsAfterLoad + 1);

      userService.gate!.complete();
      await first;
      expect(viewModel.isResolvingLeave, isFalse);
      expect(userService.profileReads, readsAfterLoad + 1);
    });

    test('listeners see the re-read start and end', () async {
      await createLoadedViewModel();
      final seen = <bool>[];
      viewModel.addListener(() => seen.add(viewModel.isResolvingLeave));

      await viewModel.resolveLeaveGroupRequirements();

      expect(seen, contains(true));
      expect(seen.last, isFalse);
    });

    test('closing the view during the re-read keeps the refusal', () async {
      await createLoadedViewModel();
      userService
        ..gate = Completer<void>()
        ..setUserState(unavailableIds: const {});

      final pending = viewModel.resolveLeaveGroupRequirements();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isResolvingLeave, isTrue);
      viewModel.dispose();
      disposedByTest = true;
      userService.gate!.complete();

      final decision = await pending;
      expect(decision.rosterIncomplete, isTrue);
    });
  });
}
