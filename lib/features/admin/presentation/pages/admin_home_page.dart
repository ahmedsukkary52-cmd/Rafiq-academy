import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/admin_admit_form.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

/// Admin home — W8 staff admit only.
///
/// H6 / A-H9: do **not** wire stats / finance / complaints / broadcast /
/// teacher-management AdminBloc events here — those writers are quarantined
/// (no product UI). Keep this surface free of parallel ops delivery.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _studentIdCtrl = TextEditingController();
  final _halaqaIdCtrl = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _halaqaIdCtrl.dispose();
    super.dispose();
  }

  void _clearFieldError() {
    if (_fieldError == null) return;
    setState(() => _fieldError = null);
  }

  void _submit() {
    final submitting =
        context.read<AdminBloc>().state.approveStudentStatus ==
        SubmissionStatus.submitting;
    if (submitting) return;

    final error = AdminAdmitFormValidation.error(
      studentId: _studentIdCtrl.text,
      halaqaId: _halaqaIdCtrl.text,
    );
    setState(() => _fieldError = error);
    if (error != null) return;

    context.read<AdminBloc>().add(
      ApproveNewStudentEvent(
        studentId: _studentIdCtrl.text.trim(),
        halaqaId: _halaqaIdCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) => p.approveStudentStatus != c.approveStudentStatus,
      listener: (context, state) {
        if (state.approveStudentStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم قبول الطالب في الحلقة');
          context.read<AdminBloc>().add(const ResetApproveStudentEvent());
          _studentIdCtrl.clear();
          _halaqaIdCtrl.clear();
          if (_fieldError != null) setState(() => _fieldError = null);
        } else if (state.approveStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.approveStudentError ?? 'تعذر قبول الطالب',
          );
          context.read<AdminBloc>().add(const ResetApproveStudentEvent());
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('نافذة المدير'),
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () => confirmAndLogout(context),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: BlocBuilder<AdminBloc, AdminState>(
            buildWhen: (p, c) =>
                p.approveStudentStatus != c.approveStudentStatus,
            builder: (context, state) {
              final submitting =
                  state.approveStudentStatus == SubmissionStatus.submitting;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    'قبول طالب في حلقة',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أدخل معرّف طالب موجود مسبقاً ومعرّف الحلقة.\n'
                    'إنشاء حساب جديد غير متاح من هنا.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _studentIdCtrl,
                          enabled: !submitting,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            labelText: 'معرّف الطالب',
                            hintText: 'studentId',
                          ),
                          onChanged: (_) => _clearFieldError(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _halaqaIdCtrl,
                          enabled: !submitting,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            labelText: 'معرّف الحلقة',
                            hintText: 'halaqaId',
                          ),
                          onChanged: (_) => _clearFieldError(),
                        ),
                        if (_fieldError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _fieldError!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'قبول',
                          isLoading: submitting,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
