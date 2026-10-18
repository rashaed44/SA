import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton Firebase services for SALO. Callable Functions are pinned to the
/// region nearest to the selected eur3 Firestore multi-region.
class SaloFirebaseServices {
  SaloFirebaseServices._();

  static final SaloFirebaseServices instance = SaloFirebaseServices._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
}
