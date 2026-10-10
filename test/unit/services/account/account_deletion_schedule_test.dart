// BUT-950: the client side of the deletion grace period.
library;

import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show IdTokenResult, User;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuth extends Mock implements AuthService {}

class _MockUser extends Mock implements User {}

class _MockToken extends Mock implements IdTokenResult {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockNotifications extends Mock implements notif.NotificationService {}

class _MockSearch extends Mock implements SearchRepository {}

class _MockOffline extends Mock implements OfflineService {}

class _Result extends Fake
    implements HttpsCallableResult<Map<dynamic, dynamic>> {
  _Result(this._data);
  final Map<dynamic, dynamic> _data;
  @override
  Map<dynamic, dynamic> get data => _data;
}

void main() {
  late _MockAuth auth;
  late _MockUser user;
  late _MockFunctions functions;
  late _MockCallable scheduleCallable;
  late _MockCallable cancelCallable;
  late _MockNotifications notifications;
  late _MockSearch search;
  late _MockOffline offline;
  late AccountDeletionService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(<String, dynamic>{});
  });

  tearDownAll(() async => TestServiceLocator.reset());

  setUp(() {
    auth = _MockAuth();
    user = _MockUser();
    functions = _MockFunctions();
    scheduleCallable = _MockCallable();
    cancelCallable = _MockCallable();
    notifications = _MockNotifications();
    search = _MockSearch();
    offline = _MockOffline();

    when(() => auth.currentUserId).thenReturn('uid-alice');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => notifications.resetForLogout()).thenAnswer((_) async {});
    when(
      () => functions.httpsCallable('scheduleAccountDeletion'),
    ).thenReturn(scheduleCallable);
    when(
      () => functions.httpsCallable('cancelAccountDeletion'),
    ).thenReturn(cancelCallable);

    if (GetIt.instance.isRegistered<notif.NotificationService>()) {
      GetIt.instance.unregister<notif.NotificationService>();
    }
    GetIt.instance.registerSingleton<notif.NotificationService>(notifications);

    service = AccountDeletionService(
      authService: auth,
      functions: functions,
      searchRepository: search,
      offlineService: offline,
    );
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<notif.NotificationService>()) {
      GetIt.instance.unregister<notif.NotificationService>();
    }
  });

  FirebaseFunctionsException failure(String code, [String? detail]) =>
      FirebaseFunctionsException(
        message: 'x',
        code: code,
        details: detail == null ? null : {'code': detail},
      );

  group('scheduleAccountDeletion', () {
    test(
      'sends the reason, stays signed in, and leaves the data alone',
      () async {
        when(
          () => scheduleCallable.call<Map<dynamic, dynamic>>(any()),
        ).thenAnswer((_) async => _Result({'scheduledFor': 1800000000000}));

        final result = await service.scheduleAccountDeletion(reason: 'flyttar');

        expect(result.status, DeletionScheduleStatus.ok);
        expect(
          result.scheduledFor,
          DateTime.fromMillisecondsSinceEpoch(1800000000000),
        );
        verify(
          () => scheduleCallable.call<Map<dynamic, dynamic>>({
            'reason': 'flyttar',
          }),
        ).called(1);
        // Signing out waits until the date has been shown.
        verifyNever(() => auth.signOut());
        // The account still exists during the window.
        verifyNever(() => search.removeUser(any()));
        verifyNever(() => offline.clearUserData(any()));
      },
    );

    test('a missing date still succeeds, with no date', () async {
      when(
        () => scheduleCallable.call<Map<dynamic, dynamic>>(any()),
      ).thenAnswer((_) async => _Result({}));
      final result = await service.scheduleAccountDeletion(reason: 'x');
      expect(result.isOk, isTrue);
      expect(result.scheduledFor, isNull);
    });

    test(
      'a stale sign-in asks for re-authentication and keeps the session',
      () async {
        when(
          () => scheduleCallable.call<Map<dynamic, dynamic>>(any()),
        ).thenThrow(failure('failed-precondition', 'requires-recent-login'));

        final result = await service.scheduleAccountDeletion(reason: 'x');

        expect(result.status, DeletionScheduleStatus.requiresReauth);
        verifyNever(() => auth.signOut());
      },
    );

    test('unavailable is a network failure and keeps the session', () async {
      when(
        () => scheduleCallable.call<Map<dynamic, dynamic>>(any()),
      ).thenThrow(failure('unavailable'));
      final result = await service.scheduleAccountDeletion(reason: 'x');
      expect(result.status, DeletionScheduleStatus.network);
      verifyNever(() => auth.signOut());
    });

    test('any other error is a failure and keeps the session', () async {
      when(
        () => scheduleCallable.call<Map<dynamic, dynamic>>(any()),
      ).thenThrow(Exception('boom'));
      final result = await service.scheduleAccountDeletion(reason: 'x');
      expect(result.status, DeletionScheduleStatus.failed);
      verifyNever(() => auth.signOut());
    });

    test('without a signed-in user nothing is called', () async {
      when(() => auth.currentUserId).thenReturn(null);
      final result = await service.scheduleAccountDeletion(reason: 'x');
      expect(result.status, DeletionScheduleStatus.failed);
      verifyNever(() => scheduleCallable.call<Map<dynamic, dynamic>>(any()));
    });
  });

  group('signOutAfterScheduling', () {
    test('resets the notification state, then signs out', () async {
      await service.signOutAfterScheduling();
      verifyInOrder([
        () => notifications.resetForLogout(),
        () => auth.signOut(),
      ]);
    });
  });

  group('cancelScheduledDeletion', () {
    test('cancels and then forces a token refresh', () async {
      when(
        () => cancelCallable.call<dynamic>(any()),
      ).thenAnswer((_) async => _Result({'cancelled': true}));
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'token');

      final result = await service.cancelScheduledDeletion();

      expect(result.isOk, isTrue);
      verifyInOrder([
        () => cancelCallable.call<dynamic>(any()),
        () => user.getIdToken(true),
      ]);
    });

    test(
      'deletion-in-progress is reported as such, without a refresh',
      () async {
        when(
          () => cancelCallable.call<dynamic>(any()),
        ).thenThrow(failure('failed-precondition', 'deletion-in-progress'));

        final result = await service.cancelScheduledDeletion();

        expect(result.status, DeletionScheduleStatus.deletionInProgress);
        verifyNever(() => user.getIdToken(any()));
      },
    );

    test('a network failure is reported as such', () async {
      when(
        () => cancelCallable.call<dynamic>(any()),
      ).thenThrow(failure('unavailable'));
      final result = await service.cancelScheduledDeletion();
      expect(result.status, DeletionScheduleStatus.network);
    });

    test(
      'a failed refresh after a server cancel still counts as cancelled',
      () async {
        when(
          () => cancelCallable.call<dynamic>(any()),
        ).thenAnswer((_) async => _Result({'cancelled': true}));
        when(() => user.getIdToken(true)).thenThrow(Exception('offline'));
        final result = await service.cancelScheduledDeletion();
        // A retry would find nothing left to cancel on the server.
        expect(result.status, DeletionScheduleStatus.ok);
      },
    );
  });

  group('scheduledDeletionAt', () {
    test('reads the claim as a date', () async {
      final token = _MockToken();
      when(
        () => token.claims,
      ).thenReturn({'deletionScheduledFor': 1800000000000});
      when(() => user.getIdTokenResult()).thenAnswer((_) async => token);

      expect(
        await service.scheduledDeletionAt(),
        DateTime.fromMillisecondsSinceEpoch(1800000000000),
      );
    });

    test('no claim means nothing is pending', () async {
      final token = _MockToken();
      when(() => token.claims).thenReturn({'admin': true});
      when(() => user.getIdTokenResult()).thenAnswer((_) async => token);
      expect(await service.scheduledDeletionAt(), isNull);
    });

    test('a failed read means nothing pending, never a lockout', () async {
      when(() => user.getIdTokenResult()).thenThrow(Exception('offline'));
      expect(await service.scheduledDeletionAt(), isNull);
    });

    test('no signed-in user means nothing pending', () async {
      when(() => auth.currentUser).thenReturn(null);
      expect(await service.scheduledDeletionAt(), isNull);
    });
  });
}
