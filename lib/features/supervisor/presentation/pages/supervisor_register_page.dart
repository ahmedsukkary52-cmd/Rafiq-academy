import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/academy_membership_invariant.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Admit an existing student into an assigned halaqa (no identity creation).
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

  void _submit() {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    final error = SupervisorMembershipFormValidation.registerError(
      studentId: _studentIdCtrl.text,
      targetHalaqaId: _halaqaId,
      assignedHalaqat: halaqat,
    );
    if (error != null) {
      setState(() => _fieldError = error);
      return;
    }
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول أولاً');
      return;
    }
    setState(() => _fieldError = null);
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
          AppSnackBar.showSuccess(context, 'تم قبول الطالب في الحلقة');
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
          Navigator.of(context).maybePop();
        } else if (state.admitStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.admitStudentError ?? 'تعذر قبول الطالب',
          );
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
        }
      },
      child: SupervisorSubpageScaffold(
        title: 'قبول طالب موجود',
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (p, c) =>
              p.halaqat != c.halaqat ||
              p.admitStudentStatus != c.admitStudentStatus,
          builder: (context, state) {
            if (state.halaqatStatus == SectionStatus.loading &&
                state.halaqat.isEmpty) {
              return const SupervisorFormSkeleton();
            }

            final submitting =
                state.admitStudentStatus == SubmissionStatus.submitting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'قبول طالب مسجّل مسبقاً',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل معرّف الطالب الحالي واختر حلقة ضمن نطاق إشرافك. '
                        'لا يتم إنشاء حساب جديد من هذه الشاشة. '
                        'الحد الأقصى ${_eastern('${AcademyMembershipInvariant.maxHalaqatPerStudent}')} حلقات للطالب.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _studentIdCtrl,
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'معرّف الطالب',
                    hintText: 'أدخل معرّف الطالب الموجود',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  onChanged: (_) {
                    if (_fieldError != null) {
                      setState(() => _fieldError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_halaqaId ?? 'none'),
                  initialValue: _resolveHalaqa(state.halaqat),
                  decoration: const InputDecoration(
                    labelText: 'الحلقة',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    for (final h in state.halaqat)
                      DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          '${h.name} (${h.studentIds.length} طالب)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: submitting
                      ? null
                      : (id) => setState(() {
                          _halaqaId = id;
                          _fieldError = null;
                        }),
                ),
                if (_fieldError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _fieldError!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: Text(submitting ? 'جاري…' : 'قبول في الحلقة'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _resolveHalaqa(List<HalaqaEntity> halaqat) {
    final current = _halaqaId;
    if (current != null && halaqat.any((h) => h.id == current)) {
      return current;
    }
    return null;
  }

  String _eastern(String input) {
    const western = '0123456789';
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final code in input.runes) {
      final ch = String.fromCharCode(code);
      final i = western.indexOf(ch);
      buffer.write(i >= 0 ? eastern[i] : ch);
    }
    return buffer.toString();
  }
}
