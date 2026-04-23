// test/unit/services/unified/operations/cooking/cooking_session_module_test.dart
//
// BUT-408 follow-up: verifies [FirebaseCookingSessionModule.updateStep]
// honours the internal debounce (coalescing rapid taps into a single write),
// no-ops cleanly when no session is active, and swallows repository errors.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_cooking_session_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../../../infrastructure/factories/recipe_factory.dart';

class _MockRepository extends Mock
    implements FirebaseCookingSessionRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockUserService extends Mock implements UserService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const currentUserId = 'user_erik';

  late _MockRepository repository;
  late _MockPermissionService permission;
  late _MockFriendsService friends;
  late _MockUserService userSvc;
  late FirebaseCookingSessionModule module;
  late Recipe recipe;

  setUpAll(() {
    registerFallbackValue(
      CookingSession(
        recipeId: 'fallback',
        recipeTitle: 'fallback',
        startedAt: DateTime.fromMillisecondsSinceEpoch(0),
        userId: 'fallback',
        userName: 'fallback',
      ),
    );
  });

  /// Default-stubbed [_MockPermissionService] — authenticated Erik with a
  /// minimal [UserProfile] so [startSession] completes without blowing up.
  void stubAuthenticated({bool authenticated = true}) {
    when(() => permission.isAuthenticated).thenReturn(authenticated);
    when(() => permission.currentUserId)
        .thenReturn(authenticated ? currentUserId : null);
    when(() => permission.currentUser).thenReturn(
      authenticated
          ? UserProfile(
              uid: currentUserId,
              displayName: 'Erik',
              email: 'erik@example.com',
              joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
              lastActiveAt: DateTime.fromMillisecondsSinceEpoch(0),
            )
          : null,
    );
    when(() => userSvc.currentUserProfile).thenReturn(
      authenticated
          ? UserProfile(
              uid: currentUserId,
              displayName: 'Erik',
              email: 'erik@example.com',
              joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
              lastActiveAt: DateTime.fromMillisecondsSinceEpoch(0),
            )
          : null,
    );
  }

  void stubGroups(List<String> groupIds) {
    when(() => friends.categoriesList).thenReturn(
      groupIds
          .map((id) => FriendCategory(
                id: id,
                ownerId: currentUserId,
                name: id,
              ))
          .toList(growable: false),
    );
  }

  setUp(() {
    repository = _MockRepository();
    permission = _MockPermissionService();
    friends = _MockFriendsService();
    userSvc = _MockUserService();

    when(() => repository.startSession(
          groupId: any(named: 'groupId'),
          session: any(named: 'session'),
        )).thenAnswer((_) async {});
    when(() => repository.endSession(
          groupId: any(named: 'groupId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
    when(() => repository.updateStep(
          groupId: any(named: 'groupId'),
          userId: any(named: 'userId'),
          currentStep: any(named: 'currentStep'),
          totalSteps: any(named: 'totalSteps'),
        )).thenAnswer((_) async {});

    stubAuthenticated();
    stubGroups(const ['family']);

    module = FirebaseCookingSessionModule(
      repository: repository,
      permissionService: permission,
      friendsService: friends,
      userService: userSvc,
    );

    recipe = RecipeFactory.build(
      id: 'recipe_1',
      title: 'Kycklinggryta',
      instructions: ['Step 1', 'Step 2', 'Step 3'],
    );
  });

  group('updateStep (debounce)', () {
    test('no-op when no active session — nothing scheduled, nothing written',
        () {
      fakeAsync((async) {
        // No startSession call → _activeGroupIds is empty.
        module.updateStep(currentStep: 1, totalSteps: 3);
        async.elapse(const Duration(seconds: 2));

        verifyNever(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            ));
      });
    });

    test('collapses three rapid calls within the window into ONE write', () {
      fakeAsync((async) {
        module.startSession(recipe);
        async.flushMicrotasks();

        module.updateStep(currentStep: 1, totalSteps: 3);
        async.elapse(const Duration(milliseconds: 100));
        module.updateStep(currentStep: 2, totalSteps: 3);
        async.elapse(const Duration(milliseconds: 100));
        module.updateStep(currentStep: 3, totalSteps: 3);

        // No write yet — still inside the window.
        verifyNever(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            ));

        async.elapse(stepDebounce + const Duration(milliseconds: 10));

        // Exactly one write, carrying the LAST pair (3 of 3).
        final captured = verify(() => repository.updateStep(
              groupId: 'family',
              userId: currentUserId,
              currentStep: captureAny(named: 'currentStep'),
              totalSteps: captureAny(named: 'totalSteps'),
            )).captured;
        expect(captured, hasLength(2)); // currentStep + totalSteps captured
        expect(captured[0], 3);
        expect(captured[1], 3);
      });
    });

    test('writes ONLY the two step fields — never the whole session node', () {
      fakeAsync((async) {
        module.startSession(recipe);
        async.flushMicrotasks();

        module.updateStep(currentStep: 2, totalSteps: 5);
        async.elapse(stepDebounce + const Duration(milliseconds: 10));

        // The repository.updateStep API accepts exactly the two int fields;
        // verifying it was called at all proves no full-node set() happened.
        verify(() => repository.updateStep(
              groupId: 'family',
              userId: currentUserId,
              currentStep: 2,
              totalSteps: 5,
            )).called(1);

        // And crucially, startSession's initial set is the ONLY full-node
        // write — no second set() after updateStep.
        verify(() => repository.startSession(
              groupId: 'family',
              session: any(named: 'session'),
            )).called(1);
      });
    });

    test('two bursts separated by a quiet window produce two writes', () {
      fakeAsync((async) {
        module.startSession(recipe);
        async.flushMicrotasks();

        // First burst.
        module.updateStep(currentStep: 1, totalSteps: 3);
        async.elapse(stepDebounce + const Duration(milliseconds: 10));

        // Quiet window between bursts.
        async.elapse(const Duration(seconds: 1));

        // Second burst.
        module.updateStep(currentStep: 2, totalSteps: 3);
        async.elapse(stepDebounce + const Duration(milliseconds: 10));

        verify(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            )).called(2);
      });
    });

    test('endSession cancels the pending debounce — no zombie write fires', () {
      fakeAsync((async) {
        module.startSession(recipe);
        async.flushMicrotasks();

        module.updateStep(currentStep: 1, totalSteps: 3);
        // Exit cooking mode before the debounce fires.
        module.endSession();
        async.flushMicrotasks();
        async.elapse(stepDebounce + const Duration(milliseconds: 50));

        // Step write must NOT have been issued — the node is gone.
        verifyNever(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            ));
      });
    });

    test('swallows repo errors silently — a failed write must not throw', () {
      fakeAsync((async) {
        when(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            )).thenThrow(StateError('offline'));

        module.startSession(recipe);
        async.flushMicrotasks();

        module.updateStep(currentStep: 1, totalSteps: 3);

        // Elapsing past the debounce should not bubble up — the flush is
        // scheduled by a Timer so any throw would surface as an uncaught
        // zone error, which fakeAsync would re-raise out of elapse().
        expect(
          () => async.elapse(stepDebounce + const Duration(milliseconds: 10)),
          returnsNormally,
        );
      });
    });

    test('unauthenticated user mid-debounce: flush is a silent no-op', () {
      fakeAsync((async) {
        module.startSession(recipe);
        async.flushMicrotasks();

        module.updateStep(currentStep: 1, totalSteps: 3);

        // Session invalidated between schedule and flush.
        stubAuthenticated(authenticated: false);

        async.elapse(stepDebounce + const Duration(milliseconds: 10));

        verifyNever(() => repository.updateStep(
              groupId: any(named: 'groupId'),
              userId: any(named: 'userId'),
              currentStep: any(named: 'currentStep'),
              totalSteps: any(named: 'totalSteps'),
            ));
      });
    });
  });
}
