import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
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

                      AppCard(
                        padding: const EdgeInsets.all(AppSizes.paddingL),
                        borderRadius: AppSizes.radiusXL,
                        hasBorder: false,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'استعادة كلمة المرور — Coming Soon',
                                    style: TextStyle(
                                      fontFamily: 'NotoNaskhArabic',
                                      fontSize: 13,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                              ),

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
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
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
                          text: TextSpan(
                            style: AppTextStyles.labelSmall,
                            children: const [
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
