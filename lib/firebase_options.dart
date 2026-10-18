import 'package:firebase_core/firebase_core.dart';

/// Firebase client identifiers for the registered SALO Android app and web app.
/// These values are client configuration, not server credentials.
class SaloFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAp4RmNklsS9fPDuh5K9WEHZ0jBm8rwEt8',
    appId: '1:736437835105:android:0ef4c1d8e6a6b755106120',
    messagingSenderId: '736437835105',
    projectId: 'salo-production-13fae',
    storageBucket: 'salo-production-13fae.firebasestorage.app',
  );

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDkP_x6EhAH90_pwAocy3yRKZPs8DCY7Z0',
    appId: '1:736437835105:web:aafa239be11e8083106120',
    authDomain: 'salo-production-13fae.firebaseapp.com',
    messagingSenderId: '736437835105',
    projectId: 'salo-production-13fae',
    storageBucket: 'salo-production-13fae.firebasestorage.app',
    measurementId: 'G-RKXZT8N228',
  );
}
