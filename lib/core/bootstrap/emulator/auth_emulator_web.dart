import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_core_web/firebase_core_web_interop.dart' as core;

@JS('firebase_auth.getAuth')
external JSObject _getAuth(JSObject app);

@JS('firebase_auth.connectAuthEmulator')
external void _connectAuthEmulator(JSObject auth, String url);

const String _service = 'butlery-auth-emulator';
const String _ignoreScripts = 'flutterfire_ignore_scripts';

/// Points Auth at the emulator inside `Firebase.initializeApp`, before Auth
/// restores a saved sign-in.
///
/// That restore asks Google about the saved user. Once Auth has made a
/// request, the SDK refuses to switch to the emulator, and FlutterFire's
/// `useAuthEmulator` swallows the refusal, so a reloaded page that was signed
/// in stayed on production. FlutterFire's own reconnect from sessionStorage
/// runs only on a `localhost` debug build.
///
/// FlutterFire initialises its services in the order they were registered,
/// starting each one before awaiting any, and Auth registers before `main`.
/// A service registered here therefore starts right after Auth's instance is
/// created and before the restore's request leaves.
void wireAuthEmulatorAtStartup(String host, int port) {
  // A registered service also gets a script loaded under its name unless
  // FlutterFire is told to skip it; there is no SDK file for this one.
  final skipped = globalContext.getProperty<JSArray<JSString>?>(
    _ignoreScripts.toJS,
  );
  globalContext.setProperty(
    _ignoreScripts.toJS,
    [...?skipped?.toDart, _service.toJS].toJS,
  );
  FirebaseCoreWeb.registerService(
    _service,
    ensurePluginInitialized: (core.App app) async =>
        _connectAuthEmulator(_getAuth(app.jsObject), 'http://$host:$port'),
  );
}
