import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/salo_user.dart';

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth,
       _firestore = firestore,
       _functions = functions;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get functions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> _checkAuthRateLimit(String email, String action) async {
    await functions.httpsCallable('checkAuthRateLimit').call(<String, Object?>{
      'email': email.trim(),
      'action': action,
    });
  }

  Future<SaloSession> login(String email, String password) async {
    try {
      await _checkAuthRateLimit(email, 'login');
      await auth.signOut();
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      var user = credential.user;
      if (user == null) {
        throw const AuthFlowException('تعذر إنشاء جلسة للحساب.');
      }
      await user.reload();
      user = auth.currentUser;
      if (user == null) {
        throw const AuthFlowException('تعذر استعادة جلسة الحساب.');
      }
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await auth.signOut();
        throw const AuthFlowException(
          'تحقق من بريدك الإلكتروني أولاً. أرسلنا رابط تحقق جديداً إن أمكن، ثم سجّل الدخول مجدداً.',
        );
      }
      return await _sessionFor(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_authMessage(error));
    } on FirebaseFunctionsException catch (error) {
      throw AuthFlowException(error.message ?? 'تعذر الاتصال بخدمة SALO.');
    } on FirebaseException catch (error) {
      throw AuthFlowException(
        error.message ?? 'تعذر تحميل ملف الحساب من Firebase.',
      );
    }
  }

  /// Creates new email/password accounts. A null result means the verification
  /// email was sent and the user must verify it before signing in.
  Future<SaloSession?> register(
    String displayName,
    String username,
    String email,
    String password,
  ) async {
    User? user;
    try {
      final normalizedEmail = email.trim();
      await _checkAuthRateLimit(normalizedEmail, 'register');
      final current = auth.currentUser;
      if (current != null &&
          current.email?.toLowerCase() == normalizedEmail.toLowerCase()) {
        user = current;
      } else {
        await auth.signOut();
        try {
          final credential = await auth.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          user = credential.user;
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') rethrow;
          final credential = await auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          user = credential.user;
          if (user == null) rethrow;
          final existingProfile = await firestore
              .collection('users')
              .doc(user.uid)
              .get();
          if (existingProfile.exists) {
            await auth.signOut();
            throw const AuthFlowException(
              'هذا البريد مسجل بالفعل. استخدم تسجيل الدخول أو إعادة تعيين كلمة المرور.',
            );
          }
        }
      }

      if (user == null) {
        throw const AuthFlowException('تعذر إنشاء حساب Firebase.');
      }
      await user.updateDisplayName(displayName.trim());
      await user.reload();
      user = auth.currentUser ?? user;
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      final profileCall = functions.httpsCallable('createUserProfile');
      await profileCall.call(<String, Object?>{
        'displayName': displayName.trim(),
        'username': username.trim(),
      });
      await auth.signOut();
      return null;
    } on AuthFlowException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_authMessage(error));
    } on FirebaseFunctionsException catch (error) {
      await auth.signOut();
      throw AuthFlowException(error.message ?? 'تعذر إعداد الملف الشخصي.');
    } on FirebaseException catch (error) {
      await auth.signOut();
      throw AuthFlowException(error.message ?? 'تعذر إعداد الملف الشخصي.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _checkAuthRateLimit(email, 'password_reset');
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep the response generic to avoid disclosing whether an account exists.
      if (error.code == 'user-not-found') return;
      throw AuthFlowException(_authMessage(error));
    }
  }

  Future<SaloUser?> restore() async {
    var user = auth.currentUser;
    if (user == null) return null;
    await user.reload();
    user = auth.currentUser;
    if (user == null) return null;
    if (!user.emailVerified) {
      await auth.signOut();
      return null;
    }
    try {
      final snapshot = await firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) {
        await auth.signOut();
        return null;
      }
      return _mapProfile(user, snapshot.data() ?? const <String, dynamic>{});
    } on FirebaseException {
      await auth.signOut();
      return null;
    }
  }

  Future<void> logout() => auth.signOut();

  Future<SaloSession> _sessionFor(User user) async {
    final snapshot = await firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) {
      await auth.signOut();
      throw const AuthFlowException(
        'الحساب يحتاج إلى إكمال ملفه. اختر «إنشاء حساب» وأدخل البريد وكلمة المرور نفسيهما لإتمام الإعداد.',
      );
    }
    return SaloSession(
      token: await user.getIdToken() ?? '',
      user: _mapProfile(user, snapshot.data() ?? const <String, dynamic>{}),
    );
  }

  SaloUser _mapProfile(User user, Map<String, dynamic> profile) => SaloUser(
    uid: user.uid,
    username: (profile['username'] ?? '').toString(),
    displayName: (profile['displayName'] ?? user.displayName ?? '').toString(),
  );

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مسجل بالفعل. استخدم تسجيل الدخول.';
      case 'weak-password':
        return 'اختر كلمة مرور أقوى لا تقل عن 8 أحرف.';
      case 'operation-not-allowed':
        return 'فعّل طريقة Email/Password في Firebase Authentication أولاً.';
      case 'too-many-requests':
        return 'محاولات كثيرة مؤقتاً. انتظر قليلاً ثم أعد المحاولة.';
      case 'network-request-failed':
        return 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.';
      default:
        return error.message ?? 'تعذر إتمام المصادقة.';
    }
  }
}
