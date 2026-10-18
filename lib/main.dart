import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options: SaloFirebaseOptions.web);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(options: SaloFirebaseOptions.android);
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    // Requires GoogleService-Info.plist for the registered iOS Firebase app.
    await Firebase.initializeApp();
  }

  runApp(const SaloApp());
}
