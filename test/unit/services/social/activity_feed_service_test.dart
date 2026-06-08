/// Unit tests for [ActivityFeedService] — privacy enforcement (BUT-906).
///
/// The load-bearing contract: `emitEvent` must NOT write an event when the
/// current user has opted out of broadcasting (`shareActivityToFeed == false`),
/// and MUST still write when they're opted in OR when the profile is null
/// (default-broadcast preserved for accounts that predate the field). A
/// regression here silently broadcasts a user who explicitly opted out — a
/// privacy leak no other test would catch.
///
/// Strategy: the service resolves `PermissionService` + `UserService` from the
/// global ServiceLocator inside `emitEvent`, so we register fakes through the
/// production-locator bridge and inject a recording repository to observe (or
/// not observe) the `addEvent` write.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/services/user_service.dart' as user_svc;

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// Records `addEvent` writes without sending. Tests assert against
/// [addedEvents]; we never `when(...)` it, so [Fake] (raises on anything
/// unimplemented) is more honest than a Mock that auto-stubs to null.
class _RecordingActivityRepo extends Fake implements ActivityEventRepository {
  final List<ActivityEvent> addedEvents = [];

  @override
  Future<void> addEvent(ActivityEvent event) async {
    addedEvents.add(event);
  }
}

UserProfile _profile({required bool shareActivityToFeed}) => UserProfile(
      uid: 'actor-1',
      displayName: 'Anna Andersson',
      email: 'anna@butlery.test',
      joinedAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 6, 1),
      shareActivityToFeed: shareActivityToFeed,
    );

void main() {
  late _RecordingActivityRepo repo;
  late MockUserService userService;
  late FakePermissionService permissionService;
  late ActivityFeedService service;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());

    repo = _RecordingActivityRepo();
    userService = MockUserService();
    permissionService = FakePermissionService();
    permissionService.setPermissionState(currentUserId: 'actor-1');

    TestServiceLocator.registerMock<PermissionService>(permissionService);
    TestServiceLocator.registerMock<user_svc.UserService>(userService);

    service = ActivityFeedService(repository: repo);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('emitEvent privacy enforcement (BUT-906)', () {
    test('opted-out user (shareActivityToFeed == false) is NOT broadcast',
        () async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(shareActivityToFeed: false));

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-1',
        'Köttbullar',
      );

      expect(repo.addedEvents, isEmpty,
          reason: 'opt-out must suppress the feed write — broadcasting an '
              'event for a user who disabled it is a privacy leak');
    });

    test('opted-in user (shareActivityToFeed == true) IS broadcast', () async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(shareActivityToFeed: true));

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-1',
        'Köttbullar',
      );

      expect(repo.addedEvents, hasLength(1),
          reason: 'opt-in is the default broadcasting behaviour');
      final event = repo.addedEvents.single;
      expect(event.actorId, equals('actor-1'));
      expect(event.recipeId, equals('recipe-1'));
      expect(event.recipeTitle, equals('Köttbullar'));
      expect(event.type, equals(ActivityEventType.cooked));
    });

    test('null profile (pre-field account) IS broadcast — default preserved',
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

      expect(repo.addedEvents, hasLength(1),
          reason: 'a null profile must not be treated as an opt-out — that '
              'would silently mute every legacy/unloaded account');
    });

    test('unauthenticated user is not broadcast (no actor)', () async {
      // Guards that the opt-out short-circuit did not accidentally move the
      // auth gate; an event with no actor must never be written.
      permissionService.setPermissionState(currentUserId: null);
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(shareActivityToFeed: true));

      await service.emitEvent(
        ActivityEventType.cooked,
        'recipe-3',
        'Lasagne',
      );

      expect(repo.addedEvents, isEmpty,
          reason: 'no current user id → no event, regardless of opt-in');
    });

    test('repository failure is swallowed — emit never throws', () async {
      // emitEvent is fire-and-forget and documents "never throws"; a failing
      // write must degrade to a logged warning, not surface to the caller.
      final throwingService = ActivityFeedService(
        repository: _ThrowingActivityRepo(),
      );
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(shareActivityToFeed: true));

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
}

class _ThrowingActivityRepo extends Fake implements ActivityEventRepository {
  @override
  Future<void> addEvent(ActivityEvent event) async {
    throw StateError('write failed');
  }
}
