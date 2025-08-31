// File generated based on google-services.json
// Real Firebase configuration for Butlery app
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Real [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options_real.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: RealFirebaseOptions.currentPlatform,
/// );
/// ```
class RealFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'RealFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'RealFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Real Firebase configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbmWnBxoQ4CYvvoMMFraZTRRD83qp8kew',
    appId: '1:976357691692:android:4a2e41f5eb04e0c2e4dc89',
    messagingSenderId: '976357691692',
    projectId: 'butlery-app-1',
    storageBucket: 'butlery-app-1.firebasestorage.app',
  );

  // For now, using the same configuration for all platforms
  // You can update these with platform-specific values if needed
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBbmWnBxoQ4CYvvoMMFraZTRRD83qp8kew',
    appId: '1:976357691692:web:4a2e41f5eb04e0c2e4dc89',
    messagingSenderId: '976357691692',
    projectId: 'butlery-app-1',
    authDomain: 'butlery-app-1.firebaseapp.com',
    storageBucket: 'butlery-app-1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBbmWnBxoQ4CYvvoMMFraZTRRD83qp8kew',
    appId: '1:976357691692:ios:4a2e41f5eb04e0c2e4dc89',
    messagingSenderId: '976357691692',
    projectId: 'butlery-app-1',
    storageBucket: 'butlery-app-1.firebasestorage.app',
    iosBundleId: 'com.example.butlery',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBbmWnBxoQ4CYvvoMMFraZTRRD83qp8kew',
    appId: '1:976357691692:macos:4a2e41f5eb04e0c2e4dc89',
    messagingSenderId: '976357691692',
    projectId: 'butlery-app-1',
    storageBucket: 'butlery-app-1.firebasestorage.app',
    iosBundleId: 'com.example.butlery',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBbmWnBxoQ4CYvvoMMFraZTRRD83qp8kew',
    appId: '1:976357691692:windows:4a2e41f5eb04e0c2e4dc89',
    messagingSenderId: '976357691692',
    projectId: 'butlery-app-1',
    authDomain: 'butlery-app-1.firebaseapp.com',
    storageBucket: 'butlery-app-1.firebasestorage.app',
  );
}