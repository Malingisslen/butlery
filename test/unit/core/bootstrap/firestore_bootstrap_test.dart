/// Unit tests for [FirestoreBootstrap] (BUT-506).
///
/// The helper is a thin wrapper around Firestore configuration extracted
/// from `main.dart`. The web IndexedDB recovery path can only execute under
/// `kIsWeb == true`, which is a compile-time constant — these tests
/// exercise the non-web bootstrap path. The web path is covered by
/// integration tests under `test/integration/web/`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/firestore_bootstrap.dart';

void main() {
  group('FirestoreBootstrap', () {
    test('configure() accepts an injected FirebaseFirestore', () async {
      final fake = FakeFirebaseFirestore();

      await expectLater(
        FirestoreBootstrap.configure(firestore: fake),
        completes,
      );
    });

    test('configure() is idempotent across hot-restart simulation', () async {
      final fake = FakeFirebaseFirestore();

      await FirestoreBootstrap.configure(firestore: fake);

      // Second call would normally throw "settings already applied" on the
      // real Firestore SDK. The helper swallows that via the outer
      // try/catch, so the second call also completes.
      await expectLater(
        FirestoreBootstrap.configure(firestore: fake),
        completes,
      );
    });

    test('configure() applies the settings before connect runs', () async {
      final firestore = _RecordingFirestore();
      FirebaseFirestore? connected;

      await FirestoreBootstrap.configure(
        firestore: firestore,
        connect: (db) {
          connected = db;
          firestore.events.add('connect');
        },
      );

      expect(connected, same(firestore));
      expect(firestore.events, ['settings', 'connect']);
    });
  });
}

class _RecordingFirestore extends FakeFirebaseFirestore {
  final events = <String>[];

  @override
  set settings(Settings settings) => events.add('settings');
}
