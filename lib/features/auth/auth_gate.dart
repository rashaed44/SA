import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/models/salo_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/salo_firebase_repository.dart';
import '../home/salo_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository auth = AuthRepository();
  final SaloFirebaseRepository repository = SaloFirebaseRepository();
  SaloUser? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      user = await auth.restore();
    } catch (_) {
      user = null;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user != null) {
      return SaloShell(
        user: user!,
        repository: repository,
        onLogout: () async {
          await auth.logout();
          if (mounted) setState(() => user = null);
        },
      );
    }
    return AuthScreen(
      auth: auth,
      onAuthenticated: (value) => setState(() => user = value),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onAuthenticated,
    required this.auth,
    super.key,
  });

  final ValueChanged<SaloUser> onAuthenticated;
  final AuthRepository auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final display = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;
  String? info;

  @override
  void dispose() {
    display.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      if (register) {
        final session = await widget.auth.register(
          display.text.trim(),
          username.text.trim(),
          email.text.trim(),
          password.text,
        );
        if (session == null) {
          password.clear();
          setState(() {
            register = false;
            info =
                'أُنشئ الحساب. تحقق من رابط البريد الإلكتروني ثم سجّل الدخول.';
          });
        } else {
          widget.onAuthenticated(session.user);
        }
      } else {
        final session = await widget.auth.login(
          email.text.trim(),
          password.text,
        );
        widget.onAuthenticated(session.user);
      }
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'تعذر إتمام العملية. تحقق من إعداد Firebase والاتصال.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final address = email.text.trim();
    if (!address.contains('@') || !address.contains('.')) {
      setState(() => error = 'اكتب بريدك الإلكتروني أولاً.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await widget.auth.sendPasswordResetEmail(address);
      if (mounted) {
        setState(
          () => info =
              'إذا كان البريد مرتبطاً بحساب، فسيصلك رابط إعادة تعيين كلمة المرور.',
        );
      }
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.forum_rounded,
                      size: 72,
                      color: SaloColors.cyan,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SALO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: SaloColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      register
                          ? 'أنشئ حسابك بالبريد الإلكتروني'
                          : 'مرحباً بعودتك',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (register) ...[
                      TextFormField(
                        controller: display,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الظاهر',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'اكتب اسمك' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().runes.length < 3
                            ? 'اسم المستخدم قصير جداً'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      validator: (value) {
                        final address = (value ?? '').trim();
                        return address.contains('@') && address.contains('.')
                            ? null
                            : 'اكتب بريداً إلكترونياً صحيحاً';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: register
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                      ),
                      validator: (value) => (value ?? '').length < 8
                          ? 'كلمة المرور 8 أحرف على الأقل'
                          : null,
                    ),
                    if (!register)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busy ? null : resetPassword,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (info != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        info!,
                        style: const TextStyle(color: Colors.lightGreenAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(register ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              register = !register;
                              error = null;
                              info = null;
                              password.clear();
                            }),
                      child: Text(
                        register
                            ? 'لديك حساب؟ تسجيل الدخول'
                            : 'إنشاء حساب جديد',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
