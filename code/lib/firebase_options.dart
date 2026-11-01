// File generated from your Firebase Android app configuration
// (google-services.json, project: kidscribe-c322f).
// Used by Firebase.initializeApp() in main.dart.
//
// Configured for ANDROID. Run on an Android emulator/device: flutter run
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'KidScribe is configured for Android. '
        'Run it on an Android emulator or device.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform. '
          'Only Android is set up for this project.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDMKS7bUjUGHewncSsjafbTi82LdMcW48M',
    appId: '1:1003502128062:android:d9ae4e461a7008e5cd47ef',
    messagingSenderId: '1003502128062',
    projectId: 'kidscribe-c322f',
    storageBucket: 'kidscribe-c322f.firebasestorage.app',
  );
}
