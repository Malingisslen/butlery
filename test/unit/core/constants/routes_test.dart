/// BUT-1412: /fileImport was declared and handled but missing from every route
/// set — so it reported itself invalid AND skipped the auth gate (FileImportView
/// built for signed-out users, unlike its sibling import modals). These tests
/// pin its registration and a regression guard that import modals stay gated.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/constants/routes.dart';

void main() {
  group('Routes — /fileImport registration (BUT-1412)', () {
    test('fileImport is a valid route', () {
      expect(Routes.isValidRoute(Routes.fileImport), isTrue);
      expect(Routes.allRoutes.contains(Routes.fileImport), isTrue);
    });

    test('fileImport requires authentication (the auth-gate fix)', () {
      expect(Routes.requiresAuth(Routes.fileImport), isTrue);
      expect(Routes.authenticatedRoutes.contains(Routes.fileImport), isTrue);
    });

    test('fileImport uses the slide-from-bottom modal animation', () {
      expect(
        Routes.getAnimationType(Routes.fileImport),
        RouteAnimationType.slideFromBottom,
      );
    });
  });

  group('Routes — invariants (BUT-1412 regression guard)', () {
    test('every bottom-slide (import-modal) route is auth-gated', () {
      // The bottom-slide set is the import/capture modals; every one of them
      // must require authentication. fileImport slipping out of this invariant
      // is exactly the bug BUT-1412 fixed.
      for (final route in Routes.bottomSlideRoutes) {
        expect(
          Routes.authenticatedRoutes.contains(route),
          isTrue,
          reason: 'import-modal route "$route" must require authentication',
        );
      }
    });
  });
}
