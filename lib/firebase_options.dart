import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Provides the Firebase configuration per platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for ${defaultTargetPlatform.name}.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCe9WKMAVBJrbz88xr9kB2JXjrKyiSSGGE',
    appId: '1:904488469938:android:36c1f725860a66c75950ab',
    messagingSenderId: '904488469938',
    projectId: 'online-store-333',
    storageBucket: 'online-store-333.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCe9WKMAVBJrbz88xr9kB2JXjrKyiSSGGE',
    appId: '1:904488469938:android:36c1f725860a66c75950ab',
    messagingSenderId: '904488469938',
    projectId: 'online-store-333',
    storageBucket: 'online-store-333.firebasestorage.app',
  );
}
