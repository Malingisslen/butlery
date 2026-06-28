/// Direct unit tests for [PermissionHelper] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure static auth/authorization guards used across services. Each takes
/// callbacks (no real auth service), so the tests are plain input→output
/// assertions. The contract that matters: a missing user / bad resource id /
/// denied permission returns the safe negative (null / false) and the happy
/// path returns the user id — and requireAuthWithError additionally pushes the
/// message through the setError callback. Explicit errorMessages are passed so
/// the tests don't depend on l10n being initialized.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/permission_helper.dart';

void main() {
  String? authed() => 'user-1';
  String? unauthed() => null;

  group('requireAuth', () {
    test('returns the user id when authenticated', () {
      expect(
        PermissionHelper.requireAuth(
          getCurrentUserId: authed,
          operationName: 'op',
        ),
        'user-1',
      );
    });

    test('returns null when not authenticated', () {
      expect(
        PermissionHelper.requireAuth(
          getCurrentUserId: unauthed,
          operationName: 'op',
          errorMessage: 'no auth',
        ),
        isNull,
      );
    });
  });

  group('requireAuthWithError', () {
    test('returns id and does not set an error when authenticated', () {
      String? captured;
      final result = PermissionHelper.requireAuthWithError(
        getCurrentUserId: authed,
        setError: (m) => captured = m,
        operationName: 'op',
      );
      expect(result, 'user-1');
      expect(captured, isNull);
    });

    test('returns null and pushes the message to setError when not authed', () {
      String? captured;
      final result = PermissionHelper.requireAuthWithError(
        getCurrentUserId: unauthed,
        setError: (m) => captured = m,
        operationName: 'op',
        errorMessage: 'please log in',
      );
      expect(result, isNull);
      expect(captured, 'please log in');
    });
  });

  group('validateResourceId', () {
    test('true for a non-empty id', () {
      expect(PermissionHelper.validateResourceId('r1', 'recipe'), isTrue);
    });

    test('false for null or empty', () {
      expect(PermissionHelper.validateResourceId(null, 'recipe'), isFalse);
      expect(PermissionHelper.validateResourceId('', 'recipe'), isFalse);
    });
  });

  group('isOwner', () {
    test('true only when both ids are present and equal', () {
      expect(
        PermissionHelper.isOwner(currentUserId: 'u1', ownerId: 'u1'),
        isTrue,
      );
    });

    test('false when ids differ', () {
      expect(
        PermissionHelper.isOwner(
          currentUserId: 'u1',
          ownerId: 'u2',
          resourceType: 'recipe',
          resourceId: 'r1',
        ),
        isFalse,
      );
    });

    test('false when either id is null', () {
      expect(
        PermissionHelper.isOwner(currentUserId: null, ownerId: 'u1'),
        isFalse,
      );
      expect(
        PermissionHelper.isOwner(currentUserId: 'u1', ownerId: null),
        isFalse,
      );
    });
  });

  group('checkPermission', () {
    test('passes through the permission callback result', () {
      expect(
        PermissionHelper.checkPermission(
          hasPermission: () => true,
          operationName: 'op',
        ),
        isTrue,
      );
      expect(
        PermissionHelper.checkPermission(
          hasPermission: () => false,
          operationName: 'op',
          resourceType: 'recipe',
          resourceId: 'r1',
        ),
        isFalse,
      );
    });
  });

  group('requireAuthAndResource', () {
    test('returns id when both auth and resource are valid', () {
      expect(
        PermissionHelper.requireAuthAndResource(
          getCurrentUserId: authed,
          resourceId: 'r1',
          resourceType: 'recipe',
          operationName: 'op',
        ),
        'user-1',
      );
    });

    test('returns null when not authenticated', () {
      expect(
        PermissionHelper.requireAuthAndResource(
          getCurrentUserId: unauthed,
          resourceId: 'r1',
          resourceType: 'recipe',
          operationName: 'op',
        ),
        isNull,
      );
    });

    test('returns null when the resource id is invalid', () {
      expect(
        PermissionHelper.requireAuthAndResource(
          getCurrentUserId: authed,
          resourceId: '',
          resourceType: 'recipe',
          operationName: 'op',
        ),
        isNull,
      );
    });
  });

  group('isAuthenticated', () {
    test('reflects whether a user id is present', () {
      expect(
        PermissionHelper.isAuthenticated(getCurrentUserId: authed),
        isTrue,
      );
      expect(
        PermissionHelper.isAuthenticated(getCurrentUserId: unauthed),
        isFalse,
      );
    });
  });

  group('getAuthenticatedUserOrDefault', () {
    test('returns the id when present', () {
      expect(
        PermissionHelper.getAuthenticatedUserOrDefault(
          getCurrentUserId: authed,
        ),
        'user-1',
      );
    });

    test('returns the default (empty by default, or custom) when absent', () {
      expect(
        PermissionHelper.getAuthenticatedUserOrDefault(
          getCurrentUserId: unauthed,
        ),
        '',
      );
      expect(
        PermissionHelper.getAuthenticatedUserOrDefault(
          getCurrentUserId: unauthed,
          defaultValue: 'anon',
        ),
        'anon',
      );
    });
  });
}
