// FlutterFire options for the staging project (butlery-app-staging, BUT-451).
// Android and web only.
// ignore_for_file: type=lint
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'The staging project is configured for Android and web only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-5ra9sPHVbXHYTi4njPnDsI2Yd2QJsJU',
    appId: '1:813015847291:android:d7189e15d6845a058e2dde',
    messagingSenderId: '813015847291',
    projectId: 'butlery-app-staging',
    storageBucket: 'butlery-app-staging.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDnMmoGn2c3G3P6YjHhWyEHGO7B7pMTGRw',
    appId: '1:813015847291:web:cdae62545c9b4fd08e2dde',
    messagingSenderId: '813015847291',
    projectId: 'butlery-app-staging',
    authDomain: 'butlery-app-staging.firebaseapp.com',
    storageBucket: 'butlery-app-staging.firebasestorage.app',
  );
}
