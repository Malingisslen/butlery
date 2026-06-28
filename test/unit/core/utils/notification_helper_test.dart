/// Direct unit tests for [NotificationHelper] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// The contract that matters: notifications are non-critical, so sending must
/// NEVER throw — a null service or a failing send is swallowed and reported as
/// `false`, a successful send returns `true`. The three convenience wrappers are
/// thin delegations onto sendSafely, so one delegation test (sendImmediateSafely)
/// proves the forwarding shape; the rest share the same swallow-and-report core.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_types.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(NotificationStrategy.recipeShared);
  });

  group('sendSafely', () {
    test(
      'returns false and does not run send when the service is null',
      () async {
        var ran = false;
        final result = await NotificationHelper.sendSafely(
          notificationService: null,
          operationName: 'op',
          send: () async => ran = true,
        );
        expect(result, isFalse);
        expect(ran, isFalse);
      },
    );

    test(
      'null service still returns false when logWarningOnNull is set',
      () async {
        final result = await NotificationHelper.sendSafely(
          notificationService: null,
          operationName: 'op',
          send: () async {},
          logWarningOnNull: true,
        );
        expect(result, isFalse);
      },
    );

    test('returns true when send completes', () async {
      final result = await NotificationHelper.sendSafely(
        notificationService: MockNotificationService(),
        operationName: 'op',
        send: () async {},
      );
      expect(result, isTrue);
    });

    test(
      'swallows a thrown error and returns false (never rethrows)',
      () async {
        final result = await NotificationHelper.sendSafely(
          notificationService: MockNotificationService(),
          operationName: 'op',
          send: () async => throw StateError('boom'),
        );
        expect(result, isFalse);
      },
    );
  });

  group('wrapper delegation', () {
    test(
      'sendImmediateSafely forwards args and returns true on success',
      () async {
        final service = MockNotificationService();
        when(
          () => service.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});

        final result = await NotificationHelper.sendImmediateSafely(
          notificationService: service,
          operationName: 'Recipe shared',
          targetUserIds: ['u1', 'u2'],
          strategy: NotificationStrategy.recipeShared,
          variables: {'recipeName': 'Pizza'},
        );

        expect(result, isTrue);
        verify(
          () => service.sendImmediateNotification(
            targetUserIds: ['u1', 'u2'],
            strategy: NotificationStrategy.recipeShared,
            variables: {'recipeName': 'Pizza'},
            additionalData: null,
            imageUrl: null,
            actions: null,
          ),
        ).called(1);
      },
    );

    test('sendImmediateSafely returns false when the service throws', () async {
      final service = MockNotificationService();
      when(
        () => service.sendImmediateNotification(
          targetUserIds: any(named: 'targetUserIds'),
          strategy: any(named: 'strategy'),
          variables: any(named: 'variables'),
          additionalData: any(named: 'additionalData'),
          imageUrl: any(named: 'imageUrl'),
          actions: any(named: 'actions'),
        ),
      ).thenThrow(StateError('network down'));

      final result = await NotificationHelper.sendImmediateSafely(
        notificationService: service,
        operationName: 'Recipe shared',
        targetUserIds: ['u1'],
        strategy: NotificationStrategy.recipeShared,
        variables: const {},
      );

      expect(result, isFalse);
    });

    test('a null service short-circuits the wrapper to false', () async {
      final result = await NotificationHelper.sendSilentSafely(
        notificationService: null,
        operationName: 'Member removed',
        targetUserIds: ['u1'],
        data: const {'type': 'member_removed'},
      );
      expect(result, isFalse);
    });
  });
}
