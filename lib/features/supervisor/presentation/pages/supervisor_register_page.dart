import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Admit existing student into an assigned halaqa via Academy Admission.
class SupervisorRegisterPage extends StatefulWidget {
  final String? preselectedHalaqaId;

  const SupervisorRegisterPage({super.key, this.preselectedHalaqaId});

  @override
  State<SupervisorRegisterPage> createState() => _SupervisorRegisterPageState();
}

class _SupervisorRegisterPageState extends State<SupervisorRegisterPage> {
  final _studentIdCtrl = TextEditingController();
  String? _halaqaId;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _halaqaId = widget.preselectedHalaqaId?.trim();
    if (_halaqaId != null && _halaqaId!.isEmpty) _halaqaId = null;
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  void _submit(List<HalaqaEntity> halaqat) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final error = SupervisorMembershipFormValidation.registerError(
      studentId: _studentIdCtrl.text,
      targetHalaqaId: _halaqaId,
      assignedHalaqat: halaqat,
    );
    setState(() => _fieldError = error);
    if (error != null) return;

    context.read<SupervisorBloc>().add(
      AdmitStudentToHalaqaEvent(
        supervisorId: auth.user.uid,
        halaqaId: _halaqaId!,
        studentId: _studentIdCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) => p.admitStudentStatus != c.admitStudentStatus,
      listener: (context, state) {
        if (state.admitStudentStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم تسجيل الطالب في الحلقة');
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
          Navigator.of(context).maybePop();
        } else if (state.admitStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.admitStudentError ?? 'تعذر تسجيل الطالب',
          );
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'تسجيل طالب',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.halaqatStatus != c.halaqatStatus ||
              p.admitStudentStatus != c.admitStudentStatus,
          builder: (context, state) {
            final halaqat = state.halaqat;
            final submitting =
                state.admitStudentStatus == SubmissionStatus.submitting;
            if (_halaqaId != null && !halaqat.any((h) => h.id == _halaqaId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _halaqaId = null);
              });
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'أدخل معرّف طالب موجود مسبقاً في النظام، ثم اختر الحلقة.\n'
                  'إنشاء حساب طالب جديد غير متاح من واجهة المشرف حالياً.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _studentIdCtrl,
                  enabled: !submitting,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: const InputDecoration(
                    labelText: 'معرّف الطالب',
                    hintText: 'studentId',
                  ),
                  onChanged: (_) {
                    if (_fieldError != null) {
                      setState(() => _fieldError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _halaqaId,
                  decoration: const InputDecoration(labelText: 'الحلقة'),
                  items: [
                    for (final h in halaqat)
                      DropdownMenuItem(
                        value: h.id,
                        child: Text(h.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: halaqat.isEmpty || submitting
                      ? null
                      : (v) => setState(() {
                          _halaqaId = v;
                          _fieldError = null;
                        }),
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
                FilledButton(
                  onPressed: halaqat.isEmpty || submitting
                      ? null
                      : () => _submit(halaqat),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تسجيل'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
