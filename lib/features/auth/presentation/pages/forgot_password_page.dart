import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/password_reset_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Password recovery through Firebase's reset email: the link opens the
/// Firebase action page where the new password is set; the user then signs in.
class ForgotPasswordPage extends StatelessWidget {
  final PasswordResetBloc? bloc;

  const ForgotPasswordPage({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    final child = Scaffold(
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
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      tooltip: 'رجوع',
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => _backToLogin(context),
                    ),
                  ),
                  const AuthBrandHeader(
                    title: 'استعادة كلمة المرور',
                    icon: Icons.lock_reset_rounded,
                  ),
                  const SizedBox(height: 32),
                  AppCard(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    borderRadius: AppSizes.radiusXL,
                    hasBorder: false,
                    child: BlocBuilder<PasswordResetBloc, PasswordResetState>(
                      builder: (context, state) => switch (state) {
                        PasswordResetEmailSent(:final email) => _ResetSentView(
                          email: email,
                        ),
                        _ => _ResetRequestForm(state: state),
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (provided != null) {
      return BlocProvider<PasswordResetBloc>.value(
        value: provided,
        child: child,
      );
    }
    return BlocProvider<PasswordResetBloc>(
      create: (_) => sl<PasswordResetBloc>(),
      child: child,
    );
  }
}

void _backToLogin(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.login);
  }
}

class _ResetRequestForm extends StatefulWidget {
  final PasswordResetState state;

  const _ResetRequestForm({required this.state});

  @override
  State<_ResetRequestForm> createState() => _ResetRequestFormState();
}

class _ResetRequestFormState extends State<_ResetRequestForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final state = widget.state;
    _emailCtrl = TextEditingController(
      text: state is PasswordResetFailure ? state.email : '',
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<PasswordResetBloc>().add(
      PasswordResetRequested(_emailCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final submitting = state is PasswordResetSubmitting;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أدخل البريد الإلكتروني المسجّل لدى الأكاديمية، وسنرسل إليك رابطاً '
            'لتعيين كلمة مرور جديدة.\n'
            'إن كنت تدخل باسم مستخدم من الأكاديمية فاطلب كلمة مرور مؤقتة '
            'جديدة من إدارة الأكاديمية.',
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (state is PasswordResetFailure) ...[
            AuthMessageBanner(message: state.message),
            const SizedBox(height: 16),
          ],
          const AuthFieldLabel('البريد الإلكتروني'),
          const SizedBox(height: 6),
          AppTextField(
            hint: 'name@example.com',
            controller: _emailCtrl,
            enabled: !submitting,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.textHint,
              size: AppSizes.iconM,
            ),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: state is PasswordResetFailure && state.retryable
                ? 'إعادة المحاولة'
                : 'إرسال رابط الاستعادة',
            onPressed: submitting ? null : _submit,
            isLoading: submitting,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: submitting ? null : () => _backToLogin(context),
            child: const Text('العودة لتسجيل الدخول'),
          ),
        ],
      ),
    );
  }
}

class _ResetSentView extends StatelessWidget {
  final String email;

  const _ResetSentView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: AppColors.success,
          size: 56,
        ),
        const SizedBox(height: 12),
        AuthMessageBanner(
          tone: AuthBannerTone.success,
          message:
              'إن كان البريد $email مسجّلاً لدى الأكاديمية فستصلك رسالة '
              'خلال دقائق. افتح الرابط لتعيين كلمة مرور جديدة، ثم سجّل الدخول بها.',
        ),
        const SizedBox(height: 8),
        Text(
          'لم تصلك الرسالة؟ تحقق من مجلد الرسائل غير المرغوب فيها.',
          textAlign: TextAlign.right,
          style: AppTextStyles.labelSmall,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'العودة لتسجيل الدخول',
          onPressed: () => _backToLogin(context),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.read<PasswordResetBloc>().add(
            const PasswordResetEditRequested(),
          ),
          child: const Text('إرسال إلى بريد آخر'),
        ),
      ],
    );
  }
}
