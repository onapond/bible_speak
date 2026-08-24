// Firebase public client configuration for the isolated development project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
          'Development Firebase options are not configured for Linux.',
        );
      default:
        throw UnsupportedError('Unsupported Firebase development platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAl9RP80Gx_y1nq15EbTeYAVOIrP6x5SR8',
    appId: '1:986844531464:web:0bd10a153db149b0b03abd',
    messagingSenderId: '986844531464',
    projectId: 'bible-speak-dev',
    authDomain: 'bible-speak-dev.firebaseapp.com',
    storageBucket: 'bible-speak-dev.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZuYmgoxNLtxiKMe5RMzSNuTLPgUVfjVI',
    appId: '1:986844531464:android:8babadf052fde01ab03abd',
    messagingSenderId: '986844531464',
    projectId: 'bible-speak-dev',
    storageBucket: 'bible-speak-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0FAf60qZfsAlnxEZ0cSSAcT8fUiE_LfA',
    appId: '1:986844531464:ios:3476cf822f9cbd73b03abd',
    messagingSenderId: '986844531464',
    projectId: 'bible-speak-dev',
    storageBucket: 'bible-speak-dev.firebasestorage.app',
    iosBundleId: 'com.onapond.biblespeak',
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = web;
}
