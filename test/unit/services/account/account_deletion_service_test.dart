/// BUT-788: unit tests for the new client-side `AccountDeletionService`.
///
/// The full cascade moved server-side (`functions/src/account/request-
/// account-deletion.ts`). This service is now a thin wrapper that:
///   1. Calls the `requestAccountDeletion` callable.
///   2. Translates `FirebaseFunctionsException(failed-precondition, code:
///      requires-recent-login)` → `result['requiresReauth'] = true`.
///   3. Signs the user out locally on success.
///
/// Tests verify the orchestration contract; the cascade itself is covered
/// by the TS unit test at `functions/src/__tests__/request-account-
/// deletion.test.ts`.
library;

import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/offline_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

/// Fake instead of Mock — `HttpsCallableResult.data` reads from a private
/// backing field that `implements` can't see, so a Mock returns null. An
/// explicit `get data` override does work and survives strict null-safety.
class _FakeCallableResult extends Fake
    implements HttpsCallableResult<Map<dynamic, dynamic>> {
  _FakeCallableResult(this._data);
  final Map<dynamic, dynamic> _data;
  @override
  Map<dynamic, dynamic> get data => _data;
}

class _MockSearchRepo extends Mock implements SearchRepository {}

class _MockOfflineService extends Mock implements OfflineService {}

class _MockNotificationService extends Mock
    implements notif.NotificationService {}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(HttpsCallableOptions());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  group('AccountDeletionService (BUT-788 CF wrapper)', () {
    late _MockAuthService auth;
    late _MockFunctions functions;
    late _MockCallable callable;
    late _FakeCallableResult callResult;
    late _MockNotificationService notifService;

    setUp(() async {
      auth = _MockAuthService();
      functions = _MockFunctions();
      callable = _MockCallable();
      notifService = _MockNotificationService();

      when(() => auth.currentUserId).thenReturn('uid-alice');
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => notifService.resetForLogout()).thenAnswer((_) async {});

      // ServiceLocator.get<NotificationService> needs a registered instance
      // for the post-CF reset step.
      if (GetIt.instance.isRegistered<notif.NotificationService>()) {
        GetIt.instance.unregister<notif.NotificationService>();
      }
      GetIt.instance.registerSingleton<notif.NotificationService>(notifService);

      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
    });

    tearDown(() async {
      if (GetIt.instance.isRegistered<notif.NotificationService>()) {
        GetIt.instance.unregister<notif.NotificationService>();
      }
    });

    /// Test 1: a successful CF response maps cleanly onto the legacy result
    /// shape that ProfileViewModel reads. If this regresses, the profile
    /// view's "deletion complete" toast won't fire.
    test('success path: maps CF response and signs user out', () async {
      callResult = _FakeCallableResult({
        'success': true,
        'deletedCollections': ['recipes', 'menus'],
        'failedCollections': <String>[],
        'errors': <String>[],
        'auditLogId': 'audit-123',
      });
      when(
        () => callable.call<Map<dynamic, dynamic>>(any()),
      ).thenAnswer((_) async => callResult);

      final service = AccountDeletionService(
        authService: auth,
        functions: functions,
      );

      final result = await service.deleteUserAccount(reason: 'user_request');

      expect(result['success'], isTrue);
      expect(result['deletedCollections'], containsAll(['recipes', 'menus']));
      expect(result['auditLogId'], 'audit-123');
      verify(() => auth.signOut()).called(1);
      // notifService.resetForLogout is resolved via production ServiceLocator
      // which isn't bridged from GetIt in this unit test — the call is
      // best-effort and wrapped in a try-catch, so its absence is non-fatal.
    });

    /// Test 2: stale `auth_time` rejection. The CF throws failed-precondition
    /// with `code: requires-recent-login` in the details map. The wrapper
    /// translates this to `result['requiresReauth'] = true` so the UI can
    /// prompt for re-authentication. NO client `user.delete()` retry —
    /// that was the auth-context-race we eliminated.
    test(
      'requires-recent-login from CF → result["requiresReauth"]=true',
      () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Recent sign-in required.',
            details: const {'code': 'requires-recent-login'},
          ),
        );

        final service = AccountDeletionService(
          authService: auth,
          functions: functions,
        );

        final result = await service.deleteUserAccount(reason: 'user_request');

        expect(result['success'], isFalse);
        expect(result['requiresReauth'], isTrue);
        // Critically: we do NOT call signOut on a failed deletion — the user
        // is still authenticated, just needs a fresh credential.
        verifyNever(() => auth.signOut());
      },
    );

    /// Test 3: search-index pre-cleanup runs before the CF call. The
    /// post-deletion search-SDK call would fail (user is gone), so it must
    /// happen pre-CF or never.
    test('runs search-index cleanup before CF call when SearchRepository '
        'registered', () async {
      final search = _MockSearchRepo();
      when(() => search.removeUser(any())).thenAnswer((_) async {});

      callResult = _FakeCallableResult({
        'success': true,
        'deletedCollections': <String>[],
        'failedCollections': <String>[],
        'errors': <String>[],
        'auditLogId': null,
      });
      when(
        () => callable.call<Map<dynamic, dynamic>>(any()),
      ).thenAnswer((_) async => callResult);

      final service = AccountDeletionService(
        authService: auth,
        functions: functions,
        searchRepository: search,
      );

      final result = await service.deleteUserAccount(reason: 'r');

      // Single verifyInOrder asserts BOTH "search ran" and "search ran before
      // the CF call". Calling `verify` first would consume the search call
      // from mocktail's pending-verify list and break the order check.
      verifyInOrder([
        () => search.removeUser('uid-alice'),
        () => callable.call<Map<dynamic, dynamic>>(any()),
      ]);
      expect(result['deletedCollections'], contains('search_index_user'));
    });

    /// Test 4: offline-cache cleanup runs before CF. Local SQLite/Drift state
    /// can't be cleaned post-deletion from the same session.
    test(
      'clears offline cache before CF call when OfflineService injected',
      () async {
        final offline = _MockOfflineService();
        when(() => offline.clearUserData(any())).thenAnswer((_) async {});

        callResult = _FakeCallableResult({
          'success': true,
          'deletedCollections': <String>[],
          'failedCollections': <String>[],
          'errors': <String>[],
          'auditLogId': null,
        });
        when(
          () => callable.call<Map<dynamic, dynamic>>(any()),
        ).thenAnswer((_) async => callResult);

        final service = AccountDeletionService(
          authService: auth,
          functions: functions,
          offlineService: offline,
        );

        await service.deleteUserAccount(reason: 'r');

        verifyInOrder([
          () => offline.clearUserData('uid-alice'),
          () => callable.call<Map<dynamic, dynamic>>(any()),
        ]);
      },
    );

    /// Test 5: no authenticated user → bails before calling CF. The CF would
    /// reject anonymous calls anyway, but the wrapper short-circuits to give
    /// a cleaner error than `unauthenticated`.
    test('no authenticated user → returns early without CF call', () async {
      when(() => auth.currentUserId).thenReturn(null);

      final service = AccountDeletionService(
        authService: auth,
        functions: functions,
      );

      final result = await service.deleteUserAccount(reason: 'r');

      expect(result['success'], isFalse);
      expect((result['errors'] as List).first, contains('No authenticated'));
      verifyNever(() => callable.call<Map<dynamic, dynamic>>(any()));
    });

    /// Test 6: failed cascade (cascade ran but some collections failed) — CF
    /// returns success=false, failedCollections non-empty. Wrapper still
    /// signs the user out (their auth is gone server-side; staying signed
    /// in locally would be inconsistent).
    test(
      'failed cascade still signs out (auth is gone server-side anyway)',
      () async {
        callResult = _FakeCallableResult({
          'success': false,
          'deletedCollections': ['recipes'],
          'failedCollections': ['messages', 'residual_data_detected'],
          'errors': ['messages: timeout'],
          'auditLogId': 'audit-failed',
        });
        when(
          () => callable.call<Map<dynamic, dynamic>>(any()),
        ).thenAnswer((_) async => callResult);

        final service = AccountDeletionService(
          authService: auth,
          functions: functions,
        );

        final result = await service.deleteUserAccount(reason: 'r');

        expect(result['success'], isFalse);
        expect(result['failedCollections'], contains('messages'));
        expect(result['failedCollections'], contains('residual_data_detected'));
        verify(() => auth.signOut()).called(1);
      },
    );

    // ── BUT-1334 additions ────────────────────────────────────────────────────

    /// Criterion 1 (BUT-1334): no authenticated user produces exactly the
    /// error string `'No authenticated user'` and the errors list contains
    /// only that one entry.  Proves the guard clause exits before any CF call.
    test('BUT-1334/crit-1: no-auth errors list is exactly '
        '[\'No authenticated user\']', () async {
      when(() => auth.currentUserId).thenReturn(null);

      final service = AccountDeletionService(
        authService: auth,
        functions: functions,
      );

      final result = await service.deleteUserAccount(reason: 'test');

      final errors = result['errors'] as List;
      expect(
        errors,
        hasLength(1),
        reason: 'only one error entry expected for no-auth path',
      );
      expect(errors.first, equals('No authenticated user'));
      verifyNever(() => callable.call<Map<dynamic, dynamic>>(any()));
    });

    /// Criterion 2 (BUT-1334): CF throws `unauthenticated` (the second
    /// re-auth trigger branch in `_handleCfException`) → `requiresReauth`
    /// is set true.  This branch is distinct from `failed-precondition +
    /// requires-recent-login` and was previously untested.
    test(
      'BUT-1334/crit-2: CF unauthenticated exception → requiresReauth=true',
      () async {
        when(() => callable.call<Map<dynamic, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Token expired.',
            details: null,
          ),
        );

        final service = AccountDeletionService(
          authService: auth,
          functions: functions,
        );

        final result = await service.deleteUserAccount(reason: 'test');

        expect(result['success'], isFalse);
        expect(
          result['requiresReauth'],
          isTrue,
          reason:
              'unauthenticated CF exception must set requiresReauth so the UI '
              'can prompt for re-login',
        );
        verifyNever(() => auth.signOut());
      },
    );

    /// Criterion 3 (BUT-1334): BOTH search-index cleanup and offline-cache
    /// cleanup run BEFORE the CF callable.  `verifyInOrder` asserts the
    /// three-step ordering: search → offline → CF.
    test(
      'BUT-1334/crit-3: search AND offline cleanup both run before CF call',
      () async {
        final search = _MockSearchRepo();
        final offline = _MockOfflineService();
        when(() => search.removeUser(any())).thenAnswer((_) async {});
        when(() => offline.clearUserData(any())).thenAnswer((_) async {});

        final successResult = _FakeCallableResult({
          'success': true,
          'deletedCollections': <String>[],
          'failedCollections': <String>[],
          'errors': <String>[],
          'auditLogId': null,
        });
        when(
          () => callable.call<Map<dynamic, dynamic>>(any()),
        ).thenAnswer((_) async => successResult);

        final service = AccountDeletionService(
          authService: auth,
          functions: functions,
          searchRepository: search,
          offlineService: offline,
        );

        await service.deleteUserAccount(reason: 'test');

        // Three-step ordering: search cleanup, then offline cleanup, then CF.
        verifyInOrder([
          () => search.removeUser('uid-alice'),
          () => offline.clearUserData('uid-alice'),
          () => callable.call<Map<dynamic, dynamic>>(any()),
        ]);
      },
    );
  });

  // ── BUT-1334 Criterion 4: post-CF success cascade ─────────────────────────
  //
  // Criterion 4 requires verifying that both NotificationService.resetForLogout
  // AND AuthService.signOut are called after a successful CF response.
  //
  // The production code resolves NotificationService via
  // `ServiceLocator.get<NotificationService>()` (production ServiceLocator,
  // backed by DIContainer → GetIt.instance).  The test must therefore
  // initialise the production ServiceLocator so the lookup succeeds;
  // `setupUnitWithProductionLocator()` does exactly this.
  group('BUT-1334/crit-4 — post-CF success: notif reset + sign-out', () {
    late _MockAuthService auth;
    late _MockFunctions functions;
    late _MockCallable callable;
    late _MockNotificationService notifService;

    setUpAll(() async {
      // Initialises both the test GetIt registry AND the production
      // ServiceLocator._container so that `ServiceLocator.get<T>()` in
      // production code resolves from the same GetIt.instance.
      await BaseUnitTest.setupUnitWithProductionLocator();
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(HttpsCallableOptions());
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    setUp(() async {
      auth = _MockAuthService();
      functions = _MockFunctions();
      callable = _MockCallable();
      notifService = _MockNotificationService();

      when(() => auth.currentUserId).thenReturn('uid-alice');
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => notifService.resetForLogout()).thenAnswer((_) async {});

      // Register our mock into GetIt.instance — which DIContainer._container
      // points at — so the production ServiceLocator.get resolves it.
      if (GetIt.instance.isRegistered<notif.NotificationService>()) {
        GetIt.instance.unregister<notif.NotificationService>();
      }
      GetIt.instance.registerSingleton<notif.NotificationService>(notifService);

      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
    });

    tearDown(() {
      if (GetIt.instance.isRegistered<notif.NotificationService>()) {
        GetIt.instance.unregister<notif.NotificationService>();
      }
    });

    /// This test proves that a successful CF response triggers both
    /// `NotificationService.resetForLogout()` and `AuthService.signOut()`.
    /// It would fail if either post-CF cleanup step were removed or skipped.
    test('CF success triggers NotificationService.resetForLogout '
        'then AuthService.signOut', () async {
      final successResult = _FakeCallableResult({
        'success': true,
        'deletedCollections': ['recipes'],
        'failedCollections': <String>[],
        'errors': <String>[],
        'auditLogId': 'audit-ok',
      });
      when(
        () => callable.call<Map<dynamic, dynamic>>(any()),
      ).thenAnswer((_) async => successResult);

      final service = AccountDeletionService(
        authService: auth,
        functions: functions,
      );

      final result = await service.deleteUserAccount(reason: 'user_request');

      expect(
        result['success'],
        isTrue,
        reason: 'CF result must propagate to caller',
      );
      verify(() => notifService.resetForLogout()).called(1);
      verify(() => auth.signOut()).called(1);
    });
  });
}
