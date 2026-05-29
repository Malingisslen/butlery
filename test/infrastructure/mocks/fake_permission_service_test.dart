/// Regression tests for FakePermissionService.setPermissionState auth toggling.
///
/// BUT-1111: setPermissionState used to unconditionally force
/// `_isAuthenticated = true` whenever `_currentUser != null`, so a test that
/// set an authenticated user could never toggle the SAME fake instance back to
/// unauthenticated — it had to build a fresh fake. That cost the BUT-1107 agent
/// five false-positive failures. These tests pin the fix: an explicit
/// `isAuthenticated: false` is honored as a force-override even when a
/// currentUser is present.
library;

import 'package:flutter_test/flutter_test.dart';

import 'production_mocks.dart';
import '../builders/user_builder.dart';

void main() {
  group('FakePermissionService.setPermissionState auth derivation', () {
    test('currentUser without explicit isAuthenticated derives authenticated',
        () {
      final svc = FakePermissionService();
      final user = UserBuilder().withId('u1').withName('Alice').build();

      svc.setPermissionState(currentUser: user);

      expect(svc.isAuthenticated, isTrue);
      expect(svc.currentUserId, equals('u1'));
    });

    test('explicit isAuthenticated:false is honored despite currentUser set',
        () {
      final svc = FakePermissionService();
      final user = UserBuilder().withId('u1').withName('Alice').build();

      svc.setPermissionState(currentUser: user, isAuthenticated: false);

      // Before BUT-1111 this was forced back to true by the currentUser block.
      expect(svc.isAuthenticated, isFalse,
          reason: 'explicit isAuthenticated:false must override the '
              'currentUser-derived default');
    });

    test('can toggle authenticated -> unauthenticated in place (BUT-1111)', () {
      final svc = FakePermissionService();
      final user = UserBuilder().withId('u1').withName('Alice').build();

      // Authenticate first.
      svc.setPermissionState(currentUser: user);
      expect(svc.isAuthenticated, isTrue);

      // Toggle the SAME instance to unauthenticated — currentUser stays sticky,
      // but the explicit false must now win (the scenario that previously
      // forced callers to build a fresh fake).
      svc.setPermissionState(isAuthenticated: false);
      expect(svc.isAuthenticated, isFalse,
          reason: 'in-place auth->unauth toggle must stick');
      // Guard against passing for the wrong reason: the currentUser must still
      // be sticky (so the toggle exercises the currentUser-present branch, not
      // a path where currentUser got cleared).
      expect(svc.currentUserId, equals('u1'));
    });

    test('explicit isAuthenticated:true with currentUser stays authenticated',
        () {
      final svc = FakePermissionService();
      final user = UserBuilder().withId('u1').withName('Alice').build();

      svc.setPermissionState(currentUser: user, isAuthenticated: true);

      expect(svc.isAuthenticated, isTrue);
    });
  });
}
