import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/emulator_bootstrap.dart';
import 'package:butlery/firebase_options.dart';

void main() {
  const production = DefaultFirebaseOptions.web;

  group('EmulatorBootstrap.options', () {
    FirebaseOptions local() => EmulatorBootstrap.options(
      production,
      releaseMode: false,
      isWeb: true,
    );

    test('is off unless the build asks for it', () {
      expect(EmulatorBootstrap.enabled, isFalse);
    });

    test('moves the app onto a demo project with no production twin', () {
      expect(local().projectId, 'demo-butlery');
      expect(local().projectId, isNot(production.projectId));
      expect(local().storageBucket, 'demo-butlery.appspot.com');
    });

    test('drops measurementId and sets no databaseURL', () {
      expect(local().measurementId, isNull);
      expect(local().databaseURL, isNull);
    });

    test('keeps the identifiers the web SDK needs to start', () {
      expect(local().apiKey, production.apiKey);
      expect(local().appId, production.appId);
      expect(local().messagingSenderId, production.messagingSenderId);
    });

    test('refuses a release build', () {
      expect(
        () => EmulatorBootstrap.options(
          production,
          releaseMode: true,
          isWeb: true,
        ),
        throwsStateError,
      );
    });

    test('refuses a native build', () {
      expect(
        () => EmulatorBootstrap.options(
          production,
          releaseMode: false,
          isWeb: false,
        ),
        throwsStateError,
      );
    });
  });

  group('EmulatorBootstrap.configure', () {
    test('refuses a release build before touching Firebase', () {
      expect(
        () => EmulatorBootstrap.configure(releaseMode: true, isWeb: true),
        throwsStateError,
      );
    });
  });
}
