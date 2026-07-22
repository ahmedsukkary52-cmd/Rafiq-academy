import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

enum _LoginMethod { email, phone, studentId }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass = true;

  _LoginMethod _method = _LoginMethod.email;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_method != _LoginMethod.email) {
      AppSnackBar.showInfo(
        context,
        'هذه الطريقة قريبًا، برجاء الدخول بالبريد الإلكتروني حاليًا',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      LoginWithEmailEvent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  void _loginByStudentId() {
    AppSnackBar.showInfo(context, 'الدخول برقم هوية الطالب قريبًا');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Stack(
            children: [
              // ── الخلفية التيل في الأعلى ──────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.36,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // ── Logo + اسم الأكاديمية ────────────────────
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'أكاديمية رفيق',
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'مرحباً بعودتك!\nسجّل دخولك للمتابعة',
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── كارت النموذج ──────────────────────────────
                      AppCard(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        borderRadius: AppSizes.radiusXL,
                        hasBorder: false,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Tabs طريقة الدخول
                              _LoginMethodTabs(
                                selected: _method,
                                onChanged: (v) => setState(() => _method = v),
                              ),
                              const SizedBox(height: 24),

                              if (_method == _LoginMethod.email) ...[
                                _buildLabel('البريد الإلكتروني'),
                                const SizedBox(height: 6),
                                AppTextField(
                                  hint: 'ahmed@rafiq.edu',
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: AppColors.textHint,
                                    size: AppSizes.iconM,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'أدخل البريد الإلكتروني';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('كلمة المرور'),
                                const SizedBox(height: 6),
                                AppTextField(
                                  hint: '••••••••',
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePass,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.textHint,
                                    size: AppSizes.iconM,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
                                    child: Icon(
                                      _obscurePass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textHint,
                                      size: AppSizes.iconM,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'أدخل كلمة المرور';
                                    }
                                    if (v.length < 6) {
                                      return 'كلمة المرور قصيرة جداً';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: const Text(
                                      'نسيت كلمة المرور؟',
                                      style: TextStyle(
                                        fontFamily: 'NotoNaskhArabic',
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                _buildLabel(
                                  _method == _LoginMethod.phone
                                      ? 'رقم الهاتف'
                                      : 'رقم الطالب',
                                ),
                                const SizedBox(height: 6),
                                AppTextField(
                                  hint: _method == _LoginMethod.phone
                                      ? '05xxxxxxxx'
                                      : 'BSM2024xxx',
                                  keyboardType: _method == _LoginMethod.phone
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                  prefixIcon: Icon(
                                    _method == _LoginMethod.phone
                                        ? Icons.phone_outlined
                                        : Icons.badge_outlined,
                                    color: AppColors.textHint,
                                    size: AppSizes.iconM,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              const SizedBox(height: 8),

                              AppButton(
                                label: 'تسجيل الدخول',
                                onPressed: isLoading ? null : _submit,
                                isLoading: isLoading,
                                leading: isLoading
                                    ? null
                                    : const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                      ),
                              ),

                              const SizedBox(height: 16),

                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'أو الدخول بـ',
                                      style: AppTextStyles.labelSmall,
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),

                              AppButton(
                                label: 'رقم هوية الطالب',
                                onPressed: _loginByStudentId,
                                backgroundColor: AppColors.secondaryBg,
                                textColor: AppColors.secondary,
                                leading: const Icon(
                                  Icons.badge_outlined,
                                  size: 18,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ليس لديك حساب؟',
                            style: AppTextStyles.labelSmall,
                          ),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.register),
                            child: const Text(
                              'إنشاء حساب',
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: RichText(
                          text: const TextSpan(
                            style: AppTextStyles.labelSmall,
                            children: [
                              TextSpan(text: 'بتسجيل الدخول أنت توافق على '),
                              TextSpan(
                                text: 'سياسة الخصوصية',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.labelLarge,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LoginMethodTabs - تبويبات طريقة الدخول
// ══════════════════════════════════════════════════════════════════════════════

class _LoginMethodTabs extends StatelessWidget {
  final _LoginMethod selected;
  final void Function(_LoginMethod) onChanged;

  const _LoginMethodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const methods = [
      (_LoginMethod.email, 'بريد إلكتروني'),
      (_LoginMethod.phone, 'رقم الهاتف'),
      (_LoginMethod.studentId, 'رقم الطالب'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: methods.map((m) {
          final isSelected = m.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  m.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
