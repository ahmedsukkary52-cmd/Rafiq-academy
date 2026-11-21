import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../accounts/data/academy_accounts_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_widgets.dart';

typedef FirstLoginSubmit = Future<void> Function(String newPassword);

/// Mirrors `memberPasswordProblem` in `functions/src/accounts/academyCredentials.ts`.
String? firstLoginPasswordProblem(String value) {
  if (value.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  if (value.length > 128) return 'كلمة المرور طويلة جداً';
  final hasLetter = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(value);
  final hasDigit = RegExp(r'[0-9\u0660-\u0669]').hasMatch(value);
  if (!hasLetter || !hasDigit) return 'كلمة المرور يجب أن تحتوي على حروف وأرقام';
  return null;
}

/// Shown until an Admin-issued temporary password is replaced. The server
/// clears the flag; the page then signs in again with the new password.
class FirstLoginPage extends StatefulWidget {
  final FirstLoginSubmit? submit;

  const FirstLoginPage({super.key, this.submit});

  @override
  State<FirstLoginPage> createState() => _FirstLoginPageState();
}

class _FirstLoginPageState extends State<FirstLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  FirstLoginSubmit get _submitter =>
      widget.submit ?? sl<AcademyAccountsRepository>().completeFirstLogin;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final password = _password.text;
    final auth = context.read<AuthBloc>();
    try {
      await _submitter(password);
      final state = auth.state;
      final email = state is AuthAuthenticated
          ? (state.user.email ?? sl<FirebaseAuth>().currentUser?.email)
          : null;
      if (email == null || email.isEmpty) {
        auth.add(const LogoutEvent());
        return;
      }
      auth.add(LoginWithEmailEvent(email: email, password: password));
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AuthHeaderBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const AuthBrandHeader(
                    title: 'خطوة أمان مطلوبة',
                    icon: Icons.lock_person_rounded,
                  ),
                  const SizedBox(height: 32),
                  AppCard(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    borderRadius: AppSizes.radiusXL,
                    hasBorder: false,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthMessageBanner(
                            tone: AuthBannerTone.info,
                            message:
                                'إدارة الأكاديمية أعطتك كلمة مرور مؤقتة للدخول '
                                'لأول مرة. لأمان حسابك يجب استبدالها الآن بكلمة '
                                'مرور خاصة بك، ثم تدخل إلى التطبيق مباشرة.',
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'ماذا أفعل؟',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1) اكتب كلمة مرور جديدة (8 أحرف على الأقل، حروف وأرقام).\n'
                            '2) أكّدها في الحقل الثاني.\n'
                            '3) اضغط «حفظ ومتابعة» للدخول إلى حسابك.',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            AuthMessageBanner(message: _error!),
                            const SizedBox(height: 16),
                          ],
                          const AuthFieldLabel('كلمة المرور الجديدة'),
                          const SizedBox(height: 6),
                          AppTextField(
                            key: const Key('first-login-password'),
                            hint: 'مثال: Basma2026',
                            controller: _password,
                            enabled: !_busy,
                            obscureText: true,
                            validator: (v) => firstLoginPasswordProblem(v ?? ''),
                          ),
                          const SizedBox(height: 16),
                          const AuthFieldLabel('تأكيد كلمة المرور'),
                          const SizedBox(height: 6),
                          AppTextField(
                            key: const Key('first-login-confirm'),
                            hint: 'أعد كتابة كلمة المرور',
                            controller: _confirm,
                            enabled: !_busy,
                            obscureText: true,
                            validator: (v) => v == _password.text
                                ? null
                                : 'كلمتا المرور غير متطابقتين',
                          ),
                          const SizedBox(height: 20),
                          AppButton(
                            label: 'حفظ ومتابعة',
                            isLoading: _busy,
                            onPressed: _busy ? null : _save,
                            leading: _busy
                                ? null
                                : const AppForwardIcon(
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.read<AuthBloc>().add(
                                    const LogoutEvent(),
                                  ),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
