/// BUT-1508: the friends service gets its permission, user and block services
/// and the lookups for notifications and analytics by constructor, and
/// `SocialModule.configureUserScope` is where they are bound. The same checks
/// run against the service the module builds and against one built directly
/// while the locator holds other instances, so a lookup that slips back to the
/// locator, at construction or later, finds the wrong one and fails.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/search/search_result.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

class _MockUserService extends Mock implements UserService {}

class _MockBlockRepository extends Mock implements FirebaseBlockRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockSocial extends Mock implements SocialEventsTracker {}

class _SpyNotificationService extends Fake implements NotificationService {
  final List<List<String>> targets = [];

  @override
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, Map<String, String>>? variablesByLocale,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    targets.add(targetUserIds);
  }
}

UserService _userServiceFor(String uid, String name) {
  final service = _MockUserService();
  when(() => service.currentUserProfile).thenReturn(_profile(uid, name));
  when(() => service.searchUsersResult(any())).thenAnswer(
    (_) async => SearchResult<UserProfile>(
      hits: [_profile('hit-from-$uid', 'Hit')],
      totalHits: 1,
      page: 0,
      totalPages: 1,
      processingTimeMs: 0,
      failed: false,
    ),
  );
  return service;
}

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  joinedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
);

final _getIt = GetIt.instance;

void put<T extends Object>(T instance) {
  if (_getIt.isRegistered<T>()) _getIt.unregister<T>();
  _getIt.registerSingleton<T>(instance);
}

void main() {
  const myUid = 'perm-uid';

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<MockFirebaseAuthRepository> putSharedServices() async {
    await TestServiceLocator.initialize();
    // Only what the module and the friends service need: the module
    // registers a long list of types that the test locator already holds.
    await _getIt.reset();
    prod.ServiceLocator.initialize(DIContainer());

    final auth = MockFirebaseAuthRepository()..setAuthState(userId: myUid);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<User?>.value(FakeUser(uid: myUid)));
    put<AuthRepository>(auth);
    put<FirestoreRepository>(FakeFirestoreRepository());
    put<FirebaseAuditRepository>(
      FirebaseAuditRepository(FirestoreSingleton.instance),
    );
    return auth;
  }

  void putDecoys() {
    put<PermissionService>(
      FakePermissionService()..setPermissionState(
        currentUserId: 'decoy-uid',
        isAuthenticated: true,
        defaultHasPermission: true,
      ),
    );
    put<UserService>(_userServiceFor('decoy', 'Decoy'));
    put<FirebaseBlockRepository>(_MockBlockRepository());
  }

  _MockBlockRepository newBlockRepo() {
    final repo = _MockBlockRepository();
    when(() => repo.blockUser(any())).thenAnswer((_) async {});
    when(
      () => repo.getBlockedUserIds(),
    ).thenAnswer((_) async => {'already-blocked'});
    when(
      () => repo.watchBlockedUserIds(),
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    return repo;
  }

  void defineSuite(
    String label,
    Future<UnifiedFriendsService> Function({
      required FakePermissionService permission,
      required UserService userService,
      required FirebaseBlockRepository blockRepo,
      required AuthRepository auth,
    })
    build,
  ) {
    group(label, () {
      late FakePermissionService permission;
      late _MockBlockRepository blockRepo;
      late UnifiedFriendsService friends;

      setUp(() async {
        final auth = await putSharedServices();
        permission = FakePermissionService()
          ..setPermissionState(
            currentUserId: myUid,
            isAuthenticated: true,
            defaultHasPermission: true,
          );
        blockRepo = newBlockRepo();
        final userService = _userServiceFor(myUid, 'Anna');
        friends = await build(
          permission: permission,
          userService: userService,
          blockRepo: blockRepo,
          auth: auth,
        );
        // The service now holds what it was given. Anything it still looks up
        // in the locator from here on lands on these.
        putDecoys();
      });

      test('the user and display name come from the services it was given, '
          'and the blocked list from its block repository', () async {
        expect(friends.currentUserId, myUid);
        expect(friends.currentUserDisplayName, 'Anna');

        await friends.initialize();
        await friends.stateStream
            .firstWhere((state) => state is FriendsStateData)
            .timeout(const Duration(seconds: 5));

        expect(friends.blockedUsers, contains('already-blocked'));
      });

      test('an invitation link names the user the permission service it was '
          'given reports', () async {
        final link = await friends.createInvitationLinkInternal('inv-1');

        expect(link, contains('from=$myUid'));
        expect(link, isNot(contains('decoy-uid')));
      });

      test('a user search asks the user service it was given', () async {
        final hits = await friends.management.searchUsers('anna');

        expect(hits.map((u) => u.uid), ['hit-from-$myUid']);
      });

      test('a category is refused when the permission service it was given '
          'says the user is not signed in', () async {
        permission.setPermissionState(
          currentUserId: myUid,
          isAuthenticated: false,
        );

        final id = await friends.categories.createCategory(name: 'Familjen');

        expect(id, isNull);
        expect(friends.categoriesList, isEmpty);
      });

      test('a block goes to the block repository it was given and is '
          'recorded by the analytics registered afterwards', () async {
        final social = _MockSocial();
        when(
          () => social.logUserBlocked(
            blockedUserId: any(named: 'blockedUserId'),
          ),
        ).thenAnswer((_) async {});
        final analytics = _MockAnalytics();
        when(() => analytics.social).thenReturn(social);
        put<AnalyticsService>(analytics);

        await friends.management.blockUser('victim-uid');
        await Future<void>.delayed(Duration.zero);

        verify(() => blockRepo.blockUser('victim-uid')).called(1);
        verify(
          () => social.logUserBlocked(blockedUserId: 'victim-uid'),
        ).called(1);
      });

      test('a friend request notifies through the notification service '
          'registered afterwards', () async {
        final spy = _SpyNotificationService();
        put<NotificationService>(spy);

        final sent = await friends.management.sendFriendRequest(
          'recipient-uid-1',
        );
        await Future<void>.delayed(Duration.zero);

        expect(sent, isTrue);
        expect(spy.targets, [
          ['recipient-uid-1'],
        ]);
      });
    });
  }

  defineSuite('built by SocialModule.configureUserScope', ({
    required permission,
    required userService,
    required blockRepo,
    required auth,
  }) async {
    put<PermissionService>(permission);
    put<UserService>(userService);
    put<FirebaseBlockRepository>(blockRepo);
    // TestServiceLocator.initialize() registered a friends service already.
    if (_getIt.isRegistered<UnifiedFriendsService>()) {
      _getIt.unregister<UnifiedFriendsService>();
    }
    await SocialModule().configureUserScope(_getIt);
    return _getIt<UnifiedFriendsService>();
  });

  defineSuite('built directly while the locator holds other instances', ({
    required permission,
    required userService,
    required blockRepo,
    required auth,
  }) async {
    putDecoys();
    return UnifiedFriendsService(
      firestoreRepository: FakeFirestoreRepository(),
      authRepository: auth,
      permissionService: permission,
      userService: userService,
      blockRepository: blockRepo,
      getNotificationService: () => _getIt.isRegistered<NotificationService>()
          ? _getIt<NotificationService>()
          : null,
      getAnalyticsService: () => _getIt.isRegistered<AnalyticsService>()
          ? _getIt<AnalyticsService>()
          : null,
    );
  });
}
