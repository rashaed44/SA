import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salo_flutter/data/repositories/auth_repository.dart';
import 'package:salo_flutter/features/auth/auth_gate.dart';

void main() {
  testWidgets('SALO auth screen renders Arabic email entry form', (
    tester,
  ) async {
    final auth = AuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AuthScreen(auth: auth, onAuthenticated: (_) {}),
        ),
      ),
    );
    expect(find.text('SALO'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
  });
}
