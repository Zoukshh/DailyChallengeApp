import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
    authDomain: 'dummy-project-id.firebaseapp.com',
    storageBucket: 'dummy-project-id.appspot.com',
    measurementId: 'G-DUMMY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyDummyKey', // Replace with actual API key from Firebase console
    appId: '1:123456789:android:abcdef123456', // Replace with actual app ID
    messagingSenderId: '123456789', // Replace with actual sender ID
    projectId: 'daily-challenge-app-2e2c9',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
  );
}
