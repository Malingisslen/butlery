/// Local test mode: points every Firebase product at the emulator suite.
///
/// Switched on with `--dart-define=USE_FIREBASE_EMULATOR=true`, web only. The
/// app then runs against a `demo-` project id, which has no production
/// counterpart, so a call that bypasses the emulator wiring fails instead of
/// reaching real data. Run book: `docs/ops/local-emulator.md`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/bootstrap/emulator/app_check_token_stub.dart'
    if (dart.library.js_interop) 'package:butlery/core/bootstrap/emulator/app_check_token_web.dart';

class EmulatorBootstrap {
  static const bool enabled = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  static const String host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const String projectId = 'demo-butlery';

  // Must match the `emulators` block in firebase.json.
  static const int authPort = 9099;
  static const int firestorePort = 8080;
  static const int functionsPort = 5001;
  static const int storagePort = 9199;

  // Every region the app instantiates FirebaseFunctions for. An instance is
  // cached per region, so wiring each one here covers later instanceFor calls.
  static const List<String> functionRegions = ['us-central1', 'europe-west1'];

  /// Production has no databaseURL, so none is set here either: the presence
  /// code that needs one stays off, as in production. measurementId is left
  /// out so analytics cannot report local runs into the production property.
  static FirebaseOptions options(
    FirebaseOptions base, {
    bool releaseMode = kReleaseMode,
    bool isWeb = kIsWeb,
  }) {
    _refuseOutsideLocalWeb(releaseMode: releaseMode, isWeb: isWeb);
    return FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: projectId,
      authDomain: base.authDomain,
      storageBucket: '$projectId.appspot.com',
    );
  }

  /// Must run right after `Firebase.initializeApp` and before anything reads
  /// or writes: Firestore refuses a host change once it has been used.
  static Future<void> configure({
    bool releaseMode = kReleaseMode,
    bool isWeb = kIsWeb,
  }) async {
    _refuseOutsideLocalWeb(releaseMode: releaseMode, isWeb: isWeb);
    final app = Firebase.app();
    if (app.options.projectId != projectId) {
      throw StateError(
        'Local test mode needs Firebase initialised with '
        'EmulatorBootstrap.options(); got project ${app.options.projectId}.',
      );
    }

    installEmulatorAppCheckToken(app.options.appId);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    await FirebaseStorage.instance.useStorageEmulator(host, storagePort);
    for (final region in functionRegions) {
      FirebaseFunctions.instanceFor(
        region: region,
      ).useFunctionsEmulator(host, functionsPort);
    }
  }

  // Native builds start a default app from google-services.json before Dart
  // runs, so local mode is limited to web.
  static void _refuseOutsideLocalWeb({
    required bool releaseMode,
    required bool isWeb,
  }) {
    if (releaseMode) {
      throw StateError(
        'USE_FIREBASE_EMULATOR must never be set in a release build.',
      );
    }
    if (!isWeb) {
      throw StateError('USE_FIREBASE_EMULATOR is supported on web only.');
    }
  }
}
