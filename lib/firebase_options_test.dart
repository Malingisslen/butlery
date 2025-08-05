// File for Firebase test configuration.
// This file provides Firebase options specifically for testing purposes.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Test [FirebaseOptions] for use with Firebase in test environment.
///
/// These options point to a test Firebase project that is isolated from
/// production data. They can be used with Firebase emulators or a dedicated
/// test Firebase project.
///
/// Example:
/// ```dart
/// import 'firebase_options_test.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: TestFirebaseOptions.currentPlatform,
/// );
/// ```
class TestFirebaseOptions {
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
          'TestFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'TestFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Test Firebase project configuration
  /// Using 'butlery-test' as the test project ID
  static const String testProjectId = 'butlery-test';
  static const String testApiKey = 'test-api-key-12345';
  static const String testAppId = 'test-app-id-12345';
  static const String testMessagingSenderId = 'test-sender-12345';
  static const String testStorageBucket = 'butlery-test.appspot.com';
  static const String testAuthDomain = 'butlery-test.firebaseapp.com';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: testApiKey,
    appId: '$testAppId-web',
    messagingSenderId: testMessagingSenderId,
    projectId: testProjectId,
    authDomain: testAuthDomain,
    storageBucket: testStorageBucket,
    measurementId: 'G-TEST12345',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: testApiKey,
    appId: '$testAppId-android',
    messagingSenderId: testMessagingSenderId,
    projectId: testProjectId,
    storageBucket: testStorageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: testApiKey,
    appId: '$testAppId-ios',
    messagingSenderId: testMessagingSenderId,
    projectId: testProjectId,
    storageBucket: testStorageBucket,
    iosBundleId: 'com.butlery.test',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: testApiKey,
    appId: '$testAppId-macos',
    messagingSenderId: testMessagingSenderId,
    projectId: testProjectId,
    storageBucket: testStorageBucket,
    iosBundleId: 'com.butlery.test',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: testApiKey,
    appId: '$testAppId-windows',
    messagingSenderId: testMessagingSenderId,
    projectId: testProjectId,
    authDomain: testAuthDomain,
    storageBucket: testStorageBucket,
    measurementId: 'G-TEST12345W',
  );
}