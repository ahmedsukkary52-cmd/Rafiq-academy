import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/domain/academy_login_identifier.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/first_login_page.dart'
    show firstLoginPasswordProblem;
import '../widgets/admin_figma_widgets.dart';
import 'admin_academy_import_page.dart';
import '../../data/admin_change_own_password.dart';

typedef PasswordChanger =
    Future<void> Function(String currentPassword, String newPassword);

/// Re-authenticates with the current password, then sets the new one.
Future<void> changeOwnPassword(String currentPassword, String newPassword) =>
    changeOwnPasswordWithAuth(
      auth: sl<FirebaseAuth>(),
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

/// How the signed-in account logs in: the academy username for internal
/// addresses, otherwise the email itself.
String? loginIdentifierLabel(String? email) {
  final value = email?.trim() ?? '';
  if (value.isEmpty) return null;
  if (AcademyLoginIdentifier.isInternalEmail(value)) {
    return 'اسم الدخول: ${value.split('@').first}';
  }
  return 'البريد: $value';
}

class AdminSettingsTab extends StatelessWidget {
  final PasswordChanger? changePassword;

  const AdminSettingsTab({super.key, this.changePassword});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final name = user?.name ?? '—';
    final initial = name.isNotEmpty ? name.characters.first : 'م';
    final identifier = loginIdentifierLabel(user?.email);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminPageHeader(
                  title: 'الإعدادات',
                  subtitle: 'حسابك وإعدادات الأكاديمية',
                ),
                AppCard(
                  onTap: null,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          initial,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'مدير الأكاديمية',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (identifier != null)
                              Text(
                                identifier,
                                key: const Key('settings-login-id'),
                                textDirection: TextDirection.rtl,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('الأمان'),
                _SettingsTile(
                  tileKey: const Key('settings-change-password'),
                  icon: Icons.lock_reset_rounded,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'يتطلب كلمة المرور الحالية',
                  onTap: user == null
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ChangePasswordSheet(
                            submit: changePassword ?? changeOwnPassword,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('إعدادات الأكاديمية'),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'وسائل الدفع',
                  subtitle: 'أرقام فودافون كاش وحساب إنستاباي لأولياء الأمور',
                  onTap: () => context.push(AppRoutes.adminPaymentDestinations),
                ),
                _SettingsTile(
                  icon: Icons.lock_open_rounded,
                  title: 'إعادة تفعيل الوصول',
                  subtitle: 'رفع إيقاف الوصول بعد تسوية المدفوعات',
                  onTap: () => context.push(AppRoutes.adminAccess),
                ),
                _SettingsTile(
                  icon: Icons.upload_file_rounded,
                  title: 'استيراد بيانات الأكاديمية',
                  subtitle: 'قالب CSV للمعلمين والطلاب وأولياء الأمور والحلقات',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminAcademyImportPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'تسجيل الخروج',
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  textColor: AppColors.error,
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  onPressed: () => confirmAndLogout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4),
    child: Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final Key? tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      key: tileKey,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
        ],
      ),
    ),
  );
}

class ChangePasswordSheet extends StatefulWidget {
  final PasswordChanger submit;

  const ChangePasswordSheet({super.key, required this.submit});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_current.text, _next.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور')),
      );
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_busy,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تغيير كلمة المرور', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Text(
                    _error!,
                    key: const Key('password-error'),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  key: const Key('password-current'),
                  controller: _current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'أدخل كلمة المرور الحالية' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('password-new'),
                  controller: _next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value == _current.text && value.isNotEmpty) {
                      return 'اختر كلمة مرور مختلفة عن الحالية';
                    }
                    return firstLoginPasswordProblem(value);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('password-confirm'),
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'كلمتا المرور غير متطابقتين' : null,
                ),
                const SizedBox(height: 16),
                AppButton(
                  key: const Key('password-save'),
                  label: _busy ? 'جارٍ الحفظ...' : 'حفظ كلمة المرور',
                  onPressed: _busy ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
