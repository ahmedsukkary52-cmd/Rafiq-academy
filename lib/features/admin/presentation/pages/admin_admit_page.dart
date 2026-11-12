import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/admin_admit_form.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

/// Staff admit form — assign a waiting student to a halaqa. New students
/// (accounts + parent link) go through the onboarding wizard instead.
class AdminAdmitPage extends StatefulWidget {
  const AdminAdmitPage({super.key});

  @override
  State<AdminAdmitPage> createState() => _AdminAdmitPageState();
}

class _AdminAdmitPageState extends State<AdminAdmitPage> {
  String? _selectedStudentId;
  String? _selectedHalaqaId;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const LoadRegistrationRequestsEvent());
      bloc.add(const LoadAdminDirectoryEvent());
    });
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

    final studentId = _selectedStudentId ?? '';
    final halaqaId = _selectedHalaqaId ?? '';
    final error = AdminAdmitFormValidation.error(
      studentId: studentId,
      halaqaId: halaqaId,
    );
    setState(() => _fieldError = error);
    if (error != null) return;

    context.read<AdminBloc>().add(
      ApproveNewStudentEvent(studentId: studentId, halaqaId: halaqaId),
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
          setState(() {
            _selectedStudentId = null;
            _selectedHalaqaId = null;
            _fieldError = null;
          });
          context.read<AdminBloc>().add(const LoadRegistrationRequestsEvent());
        } else if (state.approveStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.approveStudentError ?? 'تعذر قبول الطالب',
          );
          context.read<AdminBloc>().add(const ResetApproveStudentEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'قبول طالب',
        subtitle: 'تعيين طالب لحلقة',
        body: BlocBuilder<AdminBloc, AdminState>(
          buildWhen: (p, c) =>
              p.approveStudentStatus != c.approveStudentStatus ||
              p.registrationRequests != c.registrationRequests ||
              p.halaqatDirectory != c.halaqatDirectory ||
              p.registrationStatus != c.registrationStatus,
          builder: (context, state) {
            final submitting =
                state.approveStudentStatus == SubmissionStatus.submitting;
            final requests = state.registrationRequests;
            final halaqat = state.halaqatDirectory;
            final loadingDirectory =
                state.registrationStatus == SectionStatus.loading &&
                requests.isEmpty;

            if (loadingDirectory) {
              return const AdminFormSkeleton();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'اختر طالباً من قائمة الانتظار وحلقة للتعيين. لتسجيل طالب '
                  'جديد بحساب وولي أمر استخدم "تسجيل طالب جديد".',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('admit-open-onboarding'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('تسجيل طالب جديد'),
                  onPressed: () => context.push(AppRoutes.adminOnboardStudent),
                ),
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStudentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الطالب',
                        ),
                        hint: const Text('اختر طالباً'),
                        items: requests
                            .map(
                              (RegistrationRequestEntity r) => DropdownMenuItem(
                                value: r.studentId,
                                child: Text(
                                  r.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (v) => setState(() {
                                _selectedStudentId = v;
                                _clearFieldError();
                              }),
                      ),
                      if (requests.isEmpty) ...[
                        const SizedBox(height: 8),
                        const AdminPlaceholderCard(
                          icon: Icons.person_off_outlined,
                          title: 'لا طلاب في الانتظار',
                          message:
                              'لتسجيل طالب جديد استخدم زر "تسجيل طالب جديد" أعلاه.',
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHalaqaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الحلقة',
                        ),
                        hint: const Text('اختر حلقة'),
                        items: halaqat
                            .map(
                              (h) => DropdownMenuItem(
                                value: h.id,
                                child: Text(
                                  h.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (v) => setState(() {
                                _selectedHalaqaId = v;
                                _clearFieldError();
                              }),
                      ),
                      if (halaqat.isEmpty) ...[
                        const SizedBox(height: 8),
                        const AdminPlaceholderCard(
                          icon: Icons.menu_book_outlined,
                          title: 'لا حلقات',
                          message: 'أنشئ حلقة أولاً من مركز الإدارة.',
                        ),
                      ],
                      if (_fieldError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _fieldError!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'قبول وتعيين',
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
    );
  }
}
