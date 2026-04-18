// File generated based on GoogleService-Info.plist and google-services.json
// This is equivalent to what FlutterFire CLI generates

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbDmBiaeoMvWre81XbYGg0sbDh6tdImWw',
    appId: '1:868284115963:android:9dd49ab85e15017db8b95e',
    messagingSenderId: '868284115963',
    projectId: 'cuchum-a01e7',
    storageBucket: 'cuchum-a01e7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCMsD-npjaOlloJH7IwR3jtc6Hu8ruprNs',
    appId: '1:868284115963:ios:d6181656a2d2cad6b8b95e',
    messagingSenderId: '868284115963',
    projectId: 'cuchum-a01e7',
    storageBucket: 'cuchum-a01e7.firebasestorage.app',
    iosBundleId: 'com.cuchum.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCMsD-npjaOlloJH7IwR3jtc6Hu8ruprNs',
    appId: '1:868284115963:ios:d6181656a2d2cad6b8b95e',
    messagingSenderId: '868284115963',
    projectId: 'cuchum-a01e7',
    storageBucket: 'cuchum-a01e7.firebasestorage.app',
    iosBundleId: 'com.cuchum.app',
  );
}
