/// Unit tests for mapFirebaseErrorMessage.
///
/// Maps known FirebaseException codes to localized Swedish copy via
/// AppLocale, with a fallback chain: per-call `fallback` arg →
/// `errorGeneric`. Tests pin each known code-class branch and both
/// fallback steps.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/firebase_error_messages.dart';

FirebaseException _fe(String code) =>
    FirebaseException(plugin: 'test', code: code);

void main() {
  final l = AppLocale.current;

  group('permission-class codes → errorPermissionDenied', () {
    test('permission-denied', () {
      expect(
        mapFirebaseErrorMessage(_fe('permission-denied')),
        l.errorPermissionDenied,
      );
    });

    test('unauthorized', () {
      expect(
        mapFirebaseErrorMessage(_fe('unauthorized')),
        l.errorPermissionDenied,
      );
    });

    test('unauthenticated', () {
      expect(
        mapFirebaseErrorMessage(_fe('unauthenticated')),
        l.errorPermissionDenied,
      );
    });
  });

  group('network-class codes → errorNetwork', () {
    test('unavailable', () {
      expect(mapFirebaseErrorMessage(_fe('unavailable')), l.errorNetwork);
    });

    test('deadline-exceeded', () {
      expect(mapFirebaseErrorMessage(_fe('deadline-exceeded')), l.errorNetwork);
    });

    test('network-request-failed', () {
      expect(
        mapFirebaseErrorMessage(_fe('network-request-failed')),
        l.errorNetwork,
      );
    });
  });

  group('fallback chain', () {
    test('unknown FirebaseException code → operation fallback when given', () {
      expect(
        mapFirebaseErrorMessage(
          _fe('weird-new-code'),
          fallback: 'Kunde inte spara receptet.',
        ),
        'Kunde inte spara receptet.',
      );
    });

    test('unknown FirebaseException code → errorGeneric when no fallback', () {
      expect(
        mapFirebaseErrorMessage(_fe('weird-new-code')),
        l.errorGeneric,
      );
    });

    test('non-Firebase exception → fallback when given', () {
      expect(
        mapFirebaseErrorMessage(
          StateError('boom'),
          fallback: 'Kunde inte ladda.',
        ),
        'Kunde inte ladda.',
      );
    });

    test('non-Firebase exception → errorGeneric when no fallback', () {
      expect(
        mapFirebaseErrorMessage(StateError('boom')),
        l.errorGeneric,
      );
    });

    test('plain string → fallback or generic (treated as non-Firebase)', () {
      expect(mapFirebaseErrorMessage('something'), l.errorGeneric);
      expect(mapFirebaseErrorMessage('something', fallback: 'X'), 'X');
    });
  });
}
