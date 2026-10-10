/// Emulator lane for integration tests.
///
/// Integration tests that exercise Firestore features the in-memory fake
/// can't reproduce (`FieldValue.increment`, `FieldValue.serverTimestamp`,
/// `collectionGroup`, transactional writes) need a real
/// Firestore instance. They can't run against production Firebase either,
/// so we use the Firebase emulator as a middle ground.
///
/// Invocation:
/// * Default (mock tier): `flutter test test/integration` — uses the
///   in-memory `FakeFirebaseFirestore`; tests that import this helper
///   with `emulatorOnlySkip` are skipped.
/// * Emulator tier (BUT-1730): `integration_test/emulator_lane_test.dart` on an
///   Android emulator, with the Firestore emulator running on the host —
///   see `.github/workflows/emulator-lane.yml` for the exact command. Plain
///   `flutter test` cannot run this tier: the FlutterFire plugins have no
///   implementation on the Dart VM, so `Firebase.initializeApp` throws.
///
/// Example usage inside a `_test.dart` file:
///
/// ```dart
/// import '../../test_support/emulator_lane.dart';
///
/// void main() {
///   group('Like System with Transactions', () {
///     // ...tests that call FieldValue.increment...
///   }, skip: emulatorOnlySkip);
/// }
/// ```
///
/// The group runs in the emulator lane and is cleanly skipped on mock-tier
/// runs. Inside the group, tests call `await firestoreForLane()`
/// instead of `FakeFirebaseFirestore()`.
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../infrastructure/firebase/firebase_test_helper.dart';

/// Compile-time flag set by `--dart-define=USE_EMULATOR=true`.
const bool useEmulatorLane = bool.fromEnvironment('USE_EMULATOR');

/// Use as the `skip:` argument on a `group(...)` or `test(...)` that
/// requires the Firebase emulator.
///
/// `null` in the emulator tier (group runs), a reason string in the mock
/// tier (group is skipped with a clear reason). `test` / `group` accept
/// both a bool and a string for `skip:` — a string activates the skip,
/// `null` leaves the group running.
const Object? emulatorOnlySkip = useEmulatorLane
    ? null
    : 'Requires the Firebase emulator — runs in the emulator lane '
          '(integration_test/emulator_lane_test.dart, BUT-1730).';

FirebaseFirestore? _lane;
bool _firebaseInitialized = false;

/// Returns the Firestore instance for the current lane.
///
/// In the emulator tier this initialises Firebase once from the app's own
/// native config, routes Firestore + Auth + Storage to the emulator host, and
/// returns `FirebaseFirestore.instance`. Passing explicit options here would
/// throw `duplicate-app` on Android, where the native default app already
/// exists. In the mock tier this returns a fresh `FakeFirebaseFirestore` so
/// tests don't leak state into each other.
Future<FirebaseFirestore> firestoreForLane() async {
  if (!useEmulatorLane) {
    // Mock tier — fresh fake per call so tests don't cross-contaminate.
    return FakeFirebaseFirestore();
  }

  if (_lane != null) return _lane!;

  if (!_firebaseInitialized) {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
  }

  await FirebaseTestHelper.connectToEmulators();
  _lane = FirebaseFirestore.instance;
  return _lane!;
}

/// Deletes every document in the emulator's database. No-op in mock tier
/// (every `firestoreForLane()` call returns a fresh `FakeFirebaseFirestore`).
///
/// Uses the emulator's own reset endpoint rather than a per-collection list,
/// because suites assert on whole-collection counts and a list would miss
/// whichever collection the next suite adds.
Future<void> clearLane() async {
  if (!useEmulatorLane) return;
  final projectId = Firebase.app().options.projectId;
  final client = HttpClient();
  try {
    final request = await client.deleteUrl(
      Uri.http(
        '${FirebaseTestHelper.emulatorHost}:${FirebaseTestHelper.firestorePort}',
        '/emulator/v1/projects/$projectId/databases/(default)/documents',
      ),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != 200) {
      throw StateError(
        'Firestore emulator reset failed: HTTP ${response.statusCode}',
      );
    }
  } finally {
    client.close();
  }
}
