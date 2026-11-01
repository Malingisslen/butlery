/// Unit tests for [ActivityFeedService] — privacy enforcement (BUT-906).
///
/// The load-bearing contract: `emitEvent` must NOT write an event when the
/// current user has opted out of broadcasting (`shareActivityToFeed == false`),
/// and MUST still write when they're opted in OR when the profile is null
/// (default-broadcast preserved for accounts that predate the field). A
/// regression here silently broadcasts a user who explicitly opted out — a
/// privacy leak no other test would catch.
///
/// Strategy: the service gets `PermissionService`, `UserService` and
/// `FriendsRepository` through its constructor, with ids that differ from the
/// locator's defaults, so a service that went back to looking them up there
/// would write for the wrong user and these tests would fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/social/activity_feed_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// Records `addEvent` writes without sending. Tests assert against
/// [addedEvents]; we never `when(...)` it, so [Fake] (raises on anything
/// unimplemented) is more honest than a Mock that auto-stubs to null.
class _RecordingActivityRepo extends Fake implements ActivityEventRepository {
  final List<ActivityEvent> addedEvents = [];

  List<String>? fetchedForFriendIds;

  @override
  Future<void> addEvent(ActivityEvent event) async {
    addedEvents.add(event);
  }

  @override
  Future<List<ActivityEvent>> fetchFriendActivity({
    required List<String> friendIds,
    int limit = 20,
    DateTime? before,
  }) async {
    fetchedForFriendIds = friendIds;
    return addedEvents;
  }
}

class _FriendsRepo extends Fake implements FriendsRepository {
  _FriendsRepo(this.friendIds);

  final List<String> friendIds;
  String? askedFor;

  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    askedFor = userId;
    return friendIds;
  }
}

UserProfile _profile({
  required bool shareActivityToFeed,
  Map<String, bool> activityFeedEventTypes = const {},
  bool hasSeenActivityFeedHint = false,
}) => UserProfile(
  uid: 'actor-1',
  displayName: 'Anna Andersson',
  email: 'anna@butlery.test',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 6, 1),
  shareActivityToFeed: shareActivityToFeed,
  activityFeedEventTypes: activityFeedEventTypes,
  hasSeenActivityFeedHint: hasSeenActivityFeedHint,
);

void main() {
  late _RecordingActivityRepo repo;
  late MockUserService userService;
  late FakePermissionService permissionService;
  late ActivityFeedService service;
  late _FriendsRepo friends;

  ActivityFeedService makeService(ActivityEventRepository events) =>
      ActivityFeedService(
        repository: events,
        getPermissionService: () => permissionService,
        getUserService: () => userService,
        getFriendsRepository: () => friends,
      );

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());

    repo = _RecordingActivityRepo();
    friends = _FriendsRepo(['friend-1', 'friend-2']);
    // BaseService's signed-in preflight is the one lookup that stays.
    TestServiceLocator.registerMock<AuthRepository>(
      FakeAuthRepository()..setAuthState(userId: 'actor-1'),
    );
    userService = MockUserService();
    permissionService = FakePermissionService();
    permissionService.setPermissionState(currentUserId: 'actor-1');

    // BUT-1220: emitEvent persists the one-time hint flag on first broadcast.
    when(() => userService.markActivityFeedHintSeen()).thenAnswer((_) async {});

    service = makeService(repo);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('emitEvent privacy enforcement (BUT-906)', () {
    test(
      'opted-out user (shareActivityToFeed == false) is NOT broadcast',
      () async {
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(shareActivityToFeed: false));

        await service.emitEvent(
          ActivityEventType.cooked,
          'recipe-1',
          'Köttbullar',
        );

        expect(
          repo.addedEvents,
          isEmpty,
          reason:
              'opt-out must suppress the feed write — broadcasting an '
              'event for a user who disabled it is a privacy leak',
        );
      },
    );

    test('opted-in user (shareActivityToFeed == true) IS broadcast', () async {
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(shareActivityToFeed: true));

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-1',
        'Köttbullar',
      );

      expect(
        repo.addedEvents,
        hasLength(1),
        reason: 'opt-in is the default broadcasting behaviour',
      );
      final event = repo.addedEvents.single;
      expect(event.actorId, equals('actor-1'));
      expect(event.recipeId, equals('recipe-1'));
      expect(event.recipeTitle, equals('Köttbullar'));
      expect(event.type, equals(ActivityEventType.cooked));
    });

    test(
      'null profile (pre-field account) IS broadcast — default preserved',
      () async {
        // Accounts created before the field, or a profile not yet loaded,
        // must keep the previous broadcasting behaviour. The opt-out check is
        // `== false`, so null falls through to the emit.
        when(() => userService.currentUserProfile).thenReturn(null);

        await service.emitEvent(
          ActivityEventType.shared,
          'recipe-2',
          'Pannkakor',
        );

        expect(
          repo.addedEvents,
          hasLength(1),
          reason:
              'a null profile must not be treated as an opt-out — that '
              'would silently mute every legacy/unloaded account',
        );
      },
    );

    test('unauthenticated user is not broadcast (no actor)', () async {
      // Guards that the opt-out short-circuit did not accidentally move the
      // auth gate; an event with no actor must never be written.
      permissionService.setPermissionState(currentUserId: null);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(shareActivityToFeed: true));

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-3',
        'Lasagne',
      );

      expect(
        repo.addedEvents,
        isEmpty,
        reason: 'no current user id → no event, regardless of opt-in',
      );
    });

    test('repository failure is swallowed — emit never throws', () async {
      // emitEvent is fire-and-forget and documents "never throws"; a failing
      // write must degrade to a logged warning, not surface to the caller.
      final throwingService = makeService(_ThrowingActivityRepo());
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(shareActivityToFeed: true));

      await expectLater(
        throwingService.emitEvent(
          ActivityEventType.cooked,
          'recipe-4',
          'Risgrynsgröt',
        ),
        completes,
      );
    });
  });

  group('fetchFeed', () {
    test('reads the injected friends list for the injected user', () async {
      await service.fetchFeed();

      expect(friends.askedFor, 'actor-1');
      expect(repo.fetchedForFriendIds, ['friend-1', 'friend-2']);
    });
  });

  group('per-event-type gating (BUT-1220)', () {
    test(
      'a type explicitly disabled is NOT broadcast even with master on',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(
            shareActivityToFeed: true,
            activityFeedEventTypes: {ActivityEventType.cooked.name: false},
          ),
        );

        await service.emitEvent(
          ActivityEventType.cooked,
          'recipe-1',
          'Köttbullar',
        );

        expect(
          repo.addedEvents,
          isEmpty,
          reason:
              'an explicit per-type opt-out must suppress that type even '
              'while the master toggle is on',
        );
      },
    );

    test(
      'a type absent from the map IS broadcast (absent = enabled)',
      () async {
        // Only `cooked` is disabled; `shared` is absent → must still broadcast.
        when(() => userService.currentUserProfile).thenReturn(
          _profile(
            shareActivityToFeed: true,
            activityFeedEventTypes: {ActivityEventType.cooked.name: false},
          ),
        );

        await service.emitEvent(
          ActivityEventType.shared,
          'recipe-2',
          'Pannkakor',
        );

        expect(
          repo.addedEvents,
          hasLength(1),
          reason: 'an event type with no map entry defaults to enabled',
        );
        expect(repo.addedEvents.single.type, equals(ActivityEventType.shared));
      },
    );

    test('master-off suppresses even a per-type-enabled event', () async {
      when(() => userService.currentUserProfile).thenReturn(
        _profile(
          shareActivityToFeed: false,
          activityFeedEventTypes: {ActivityEventType.cooked.name: true},
        ),
      );

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-3',
        'Lasagne',
      );

      expect(
        repo.addedEvents,
        isEmpty,
        reason:
            'the master toggle overrides per-type opt-ins — off means '
            'nothing broadcasts',
      );
    });
  });

  group('one-time first-event hint (BUT-1220)', () {
    test(
      'first successful broadcast triggers the hint and persists the flag',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(shareActivityToFeed: true, hasSeenActivityFeedHint: false),
        );

        expect(service.firstEventHint.value, isFalse);

        await service.emitEvent(
          ActivityEventType.cooked,
          'recipe-1',
          'Köttbullar',
        );

        expect(
          service.firstEventHint.value,
          isTrue,
          reason: 'the in-session hint notifier fires on the first broadcast',
        );
        verify(() => userService.markActivityFeedHintSeen()).called(1);
      },
    );

    test('a user who already saw the hint does not re-trigger it', () async {
      when(() => userService.currentUserProfile).thenReturn(
        _profile(shareActivityToFeed: true, hasSeenActivityFeedHint: true),
      );

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-1',
        'Köttbullar',
      );

      expect(
        service.firstEventHint.value,
        isFalse,
        reason: 'the durable flag suppresses the hint on subsequent runs',
      );
      verifyNever(() => userService.markActivityFeedHintSeen());
    });

    test(
      'a suppressed event (per-type off) does NOT trigger the hint',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(
            shareActivityToFeed: true,
            activityFeedEventTypes: {ActivityEventType.cooked.name: false},
            hasSeenActivityFeedHint: false,
          ),
        );

        await service.emitEvent(
          ActivityEventType.cooked,
          'recipe-1',
          'Köttbullar',
        );

        expect(
          service.firstEventHint.value,
          isFalse,
          reason:
              'the hint must only fire when an event was actually '
              'broadcast — a gated-out event is not a first broadcast',
        );
        verifyNever(() => userService.markActivityFeedHintSeen());
      },
    );
  });
}

class _ThrowingActivityRepo extends Fake implements ActivityEventRepository {
  @override
  Future<void> addEvent(ActivityEvent event) async {
    throw StateError('write failed');
  }
}
