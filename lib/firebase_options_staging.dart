// FlutterFire options for the staging project (butlery-app-staging, BUT-451).
// Android only: the staging app is not built for other platforms.
// ignore_for_file: type=lint
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'The staging project is configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-5ra9sPHVbXHYTi4njPnDsI2Yd2QJsJU',
    appId: '1:813015847291:android:d7189e15d6845a058e2dde',
    messagingSenderId: '813015847291',
    projectId: 'butlery-app-staging',
    storageBucket: 'butlery-app-staging.firebasestorage.app',
  );
}
