import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/app_flavor.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_widgets.dart';

/// D1: sign-in only. Accounts are created by the academy administration.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isTrial = currentAppFlavor() == AppFlavor.trial;
    return Scaffold(
      body: Stack(
        children: [
          const AuthHeaderBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const AuthBrandHeader(
                    title: 'أهلاً بعودتك\nسجّل دخولك للمتابعة',
                  ),
                  if (isTrial) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'نسخة تجربة الأكاديمية (BASMA Trial)\n'
                        'متصلة بمشروع rafiq-academy. العمليات التي تعتمد على '
                        'Cloud Functions لن تكتمل حتى يتم نشر الـ Backend بموافقة مستقلة.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const _LoginForm(),
                  const SizedBox(height: 16),
                  Text(
                    'إنشاء الحسابات يتم بواسطة إدارة الأكاديمية فقط',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      LoginWithEmailEvent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return AppCard(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          borderRadius: AppSizes.radiusXL,
          hasBorder: false,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LoginStatusBanner(state: state),
                const AuthFieldLabel('اسم المستخدم'),
                const SizedBox(height: 6),
                AppTextField(
                  key: const Key('login-identifier'),
                  hint: 'مثال: ahmed.mohamed.ali',
                  controller: _emailCtrl,
                  enabled: !isLoading,
                  keyboardType: TextInputType.text,
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.textHint,
                    size: AppSizes.iconM,
                  ),
                  validator: AuthValidators.loginIdentifier,
                ),
                const SizedBox(height: 16),
                const AuthFieldLabel('كلمة المرور'),
                const SizedBox(height: 6),
                AppTextField(
                  key: const Key('login-password'),
                  hint: '••••••••',
                  controller: _passwordCtrl,
                  enabled: !isLoading,
                  obscureText: _obscurePass,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.textHint,
                    size: AppSizes.iconM,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscurePass
                        ? 'إظهار كلمة المرور'
                        : 'إخفاء كلمة المرور',
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textHint,
                      size: AppSizes.iconM,
                    ),
                  ),
                  validator: AuthValidators.password,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  key: const Key('login-submit'),
                  label: state is AuthError && state.isRetryable
                      ? 'إعادة المحاولة'
                      : 'تسجيل الدخول',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                  // In RTL, [leading] sits to the right of the label.
                  leading: isLoading
                      ? null
                      : const AppForwardIcon(color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Login failure, or the reason for a forced sign-out.
class _LoginStatusBanner extends StatelessWidget {
  final AuthState state;

  const _LoginStatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final message = switch (state) {
      AuthError(:final message) => message,
      AuthUnauthenticated(:final message?) => message,
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AuthMessageBanner(message: message),
    );
  }
}
