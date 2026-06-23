/// Unit tests for sanitizeErrorForUser.
///
/// Maps raw exception strings to Swedish user-facing copy via AppLocale.
/// Tests pin which Swedish copy each error class lands on (network,
/// timeout, auth, permission, not-found, server, generic). Strings are
/// asserted by AppLocale lookup, not literal — so localization edits
/// don't break the contract.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';

void main() {
  final l = AppLocale.current;

  group('network errors', () {
    test('SocketException → errorNetwork', () {
      expect(sanitizeErrorForUser('SocketException: failed'), l.errorNetwork);
    });

    test('"connection refused" → errorNetwork', () {
      expect(sanitizeErrorForUser('Connection refused'), l.errorNetwork);
    });

    test('plain "network" → errorNetwork', () {
      expect(sanitizeErrorForUser('network down'), l.errorNetwork);
    });

    test('"no internet" → errorNetwork', () {
      expect(sanitizeErrorForUser('no internet'), l.errorNetwork);
    });

    test('"connection failed" → errorNetwork', () {
      expect(sanitizeErrorForUser('connection failed'), l.errorNetwork);
    });
  });

  group('timeout', () {
    test('"timeout" → errorTimeout', () {
      expect(sanitizeErrorForUser('timeout'), l.errorTimeout);
    });

    test('"timed out" → errorTimeout', () {
      expect(sanitizeErrorForUser('request timed out'), l.errorTimeout);
    });
  });

  group('auth', () {
    test('"unauthenticated" → errorAuthentication', () {
      expect(sanitizeErrorForUser('unauthenticated'), l.errorAuthentication);
    });

    test('"sign in" → errorAuthentication', () {
      expect(sanitizeErrorForUser('please sign in'), l.errorAuthentication);
    });

    test('"auth expired" → errorAuthentication', () {
      expect(sanitizeErrorForUser('auth token expired'), l.errorAuthentication);
    });
  });

  group('permission', () {
    test('"permission" → errorPermissionDenied', () {
      expect(
        sanitizeErrorForUser('permission denied'),
        l.errorPermissionDenied,
      );
    });

    test('"unauthorized" → errorPermissionDenied', () {
      expect(sanitizeErrorForUser('unauthorized'), l.errorPermissionDenied);
    });

    test('"forbidden" → errorPermissionDenied', () {
      expect(sanitizeErrorForUser('forbidden'), l.errorPermissionDenied);
    });
  });

  group('not-found', () {
    test('"not found" → errorNotFound', () {
      expect(sanitizeErrorForUser('not found'), l.errorNotFound);
    });

    test('"404" → errorNotFound', () {
      expect(sanitizeErrorForUser('HTTP 404'), l.errorNotFound);
    });
  });

  group('server', () {
    test('"500" → errorServer', () {
      expect(sanitizeErrorForUser('Got 500'), l.errorServer);
    });

    test('"503" → errorServer', () {
      expect(sanitizeErrorForUser('503 Service Unavailable'), l.errorServer);
    });

    test('"server error" → errorServer', () {
      expect(sanitizeErrorForUser('internal server error'), l.errorServer);
    });
  });

  group('fallback', () {
    test('unknown error → errorGeneric', () {
      expect(sanitizeErrorForUser('hyperspace overload'), l.errorGeneric);
    });

    test('handles non-String inputs via toString()', () {
      expect(sanitizeErrorForUser(StateError('not found')), l.errorNotFound);
    });
  });
}
