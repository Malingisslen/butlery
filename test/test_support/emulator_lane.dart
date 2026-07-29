/// Emulator lane for integration tests.
///
/// Integration tests that exercise Firestore features the in-memory fake
/// can't reproduce (`FieldValue.increment`, `FieldValue.serverTimestamp`,
/// `collectionGroup`, transactional writes, security rules) need a real
/// Firestore instance. They can't run against production Firebase either,
/// so we use the Firebase emulator as a middle ground.
///
/// Invocation:
/// * Default (mock tier): `flutter test test/integration` — uses the
///   in-memory `FakeFirebaseFirestore`; tests that import this helper
///   with `emulatorOnlySkip` are skipped.
/// * Emulator tier: `flutter test test/integration --dart-define=USE_EMULATOR=true`
///   with `firebase emulators:start --only auth,firestore,storage` running.
///
/// BUT-1695 — READ THIS BEFORE COUNTING ON THIS LANE. It runs NOWHERE in CI,
/// and it cannot be turned on with a flag:
///   * `scripts/run_e2e_tests.sh --tier emulator` (and the `emulator` leg of
///     `.github/workflows/e2e_tests.yml`) only ever runs `test/e2e`. It has
///     never run `test/integration`. That claim used to live in this comment
///     and is what made the gap invisible.
///   * The `integration-tests` job in `.github/workflows/test.yml` does run
///     `test/integration` with the emulators up, but in MOCK tier, because
///     passing the define makes `Firebase.initializeApp` below throw
///     `PlatformException(channel-error, ...FirebaseCoreHostApi.initializeCore)`
///     — `flutter test` runs on the Dart VM, where the FlutterFire plugins have
///     no implementation to bind to. Verified locally on the exact command.
/// Making the lane real needs a host that loads the plugins (`integration_test`
/// on a device/emulator) or a pure-Dart Firestore client. Until then, treat
/// every `emulatorOnlySkip` group as UNVERIFIED, not as covered.
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
/// The group runs on the emulator CI leg and is cleanly skipped on
/// mock-tier local runs. Inside the group, tests call `await firestoreForLane()`
/// instead of `FakeFirebaseFirestore()`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infrastructure/firebase/firebase_test_helper.dart';

/// Compile-time flag set by `--dart-define=USE_EMULATOR=true`.
///
/// Matches the `USE_EMULATOR` define that `scripts/run_e2e_tests.sh --tier
/// emulator` passes to `flutter test` when running the emulator CI leg.
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
    : 'Requires Firebase emulator — run with '
          '`flutter test --dart-define=USE_EMULATOR=true`. NOT covered by any '
          'CI job today, and the define does not work under `flutter test` '
          '(BUT-1695) — treat this group as unverified.';

FirebaseFirestore? _lane;
bool _firebaseInitialized = false;

/// Returns the Firestore instance for the current lane.
///
/// In the emulator tier this initialises Firebase once (with fake options
/// — the emulator doesn't validate them), routes Firestore + Auth + Storage
/// to the local emulator host, and returns `FirebaseFirestore.instance`.
/// In the mock tier this returns a fresh `FakeFirebaseFirestore` so tests
/// don't leak state into each other.
///
/// Call from `setUp` (for fresh state per test) or `setUpAll` combined
/// with a per-test `FirebaseTestHelper.clearFirestoreData()` reset.
Future<FirebaseFirestore> firestoreForLane() async {
  if (!useEmulatorLane) {
    // Mock tier — fresh fake per call so tests don't cross-contaminate.
    return FakeFirebaseFirestore();
  }

  if (_lane != null) return _lane!;

  if (!_firebaseInitialized) {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'emulator-test-key',
        appId: 'emulator-test-app',
        messagingSenderId: 'emulator-sender',
        projectId: 'butlery-emulator-test',
      ),
    );
    _firebaseInitialized = true;
  }

  await FirebaseTestHelper.connectToEmulators();
  _lane = FirebaseFirestore.instance;
  return _lane!;
}

/// Clears all emulator data. No-op in mock tier (every `firestoreForLane()`
/// call returns a fresh `FakeFirebaseFirestore` anyway).
///
/// Call from `setUp` in emulator-lane tests so each test starts clean.
Future<void> clearLane() async {
  if (!useEmulatorLane) return;
  await FirebaseTestHelper.clearFirestoreData();
}
