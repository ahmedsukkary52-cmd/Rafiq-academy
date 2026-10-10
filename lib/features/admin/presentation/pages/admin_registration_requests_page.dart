import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

/// Registration queue — W8 Option A: students without halaqa membership.
class AdminRegistrationRequestsPage extends StatefulWidget {
  const AdminRegistrationRequestsPage({super.key});

  @override
  State<AdminRegistrationRequestsPage> createState() =>
      _AdminRegistrationRequestsPageState();
}

class _AdminRegistrationRequestsPageState
    extends State<AdminRegistrationRequestsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const LoadRegistrationRequestsEvent());
      bloc.add(const LoadAdminDirectoryEvent());
      if (bloc.state.teachersStatus != SectionStatus.loaded) {
        bloc.add(const LoadAllTeachersEvent());
      }
    });
  }

  Future<void> _showApproveSheet(RegistrationRequestEntity request) async {
    final state = context.read<AdminBloc>().state;
    if (state.halaqatDirectory.isEmpty) {
      AppSnackBar.showError(context, 'لا توجد حلقات — أنشئ حلقة أولاً');
      return;
    }

    String? halaqaId = state.halaqatDirectory.first.id;
    String? teacherId;
    String? supervisorId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final halaqa = state.halaqatDirectory.firstWhere(
              (h) => h.id == halaqaId,
            );
            teacherId ??= halaqa.teacherId;
            supervisorId ??= halaqa.supervisorId;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'قبول ${request.name}',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: halaqaId,
                    decoration: const InputDecoration(labelText: 'الحلقة'),
                    items: state.halaqatDirectory
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheetState(() {
                      halaqaId = v;
                      final selected = state.halaqatDirectory.firstWhere(
                        (h) => h.id == v,
                      );
                      teacherId = selected.teacherId;
                      supervisorId = selected.supervisorId;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: teacherId!.isEmpty ? null : teacherId,
                    decoration: const InputDecoration(labelText: 'المعلم'),
                    items: state.teachers
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.uid,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheetState(() => teacherId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: supervisorId!.isEmpty ? null : supervisorId,
                    decoration: const InputDecoration(labelText: 'المشرف'),
                    items: state.supervisorsDirectory
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.uid,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheetState(() => supervisorId = v),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'تأكيد القبول',
                    onPressed: halaqaId == null
                        ? null
                        : () {
                            context.read<AdminBloc>().add(
                              ApproveRegistrationRequestEvent(
                                studentId: request.studentId,
                                halaqaId: halaqaId!,
                                teacherId: teacherId,
                                supervisorId: supervisorId,
                              ),
                            );
                            Navigator.pop(context);
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) =>
          p.registrationActionStatus != c.registrationActionStatus,
      listener: (context, state) {
        if (state.registrationActionStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم تحديث الطلب');
          context.read<AdminBloc>().add(const ResetRegistrationActionEvent());
        } else if (state.registrationActionStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.registrationActionError ?? 'تعذر تنفيذ العملية',
          );
          context.read<AdminBloc>().add(const ResetRegistrationActionEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'طلبات التسجيل',
        subtitle: 'بانتظار الموافقة',
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            if (state.registrationStatus == SectionStatus.loading) {
              return const AdminRegistrationRequestsSkeleton();
            }
            if (state.registrationStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.registrationError ?? 'تعذر التحميل',
                onRetry: () => context.read<AdminBloc>().add(
                  const LoadRegistrationRequestsEvent(),
                ),
              );
            }

            final pending = state.registrationRequests;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AdminGradientHeroCard(
                  eyebrow: 'الانتظار',
                  headline: '${formatAdminCount(pending.length)} طلب',
                  metrics: [
                    AdminHeroMetric(
                      value: '${adminFormatCount(pending.length)}',
                      label: 'بانتظار التعيين',
                    ),
                    AdminHeroMetric(
                      value: pending.isEmpty ? '—' : 'نشط',
                      label: 'مسار القبول',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (pending.isEmpty)
                  const AdminPlaceholderCard(
                    icon: Icons.inbox_outlined,
                    title: 'لا طلبات معلقة',
                    message: 'لا توجد طلبات تسجيل بانتظار التعيين حالياً.',
                  )
                else
                  ...pending.map(
                    (r) => _RequestCard(
                      request: r,
                      busy:
                          state.registrationActionStatus ==
                          SubmissionStatus.submitting,
                      onApprove: () => _showApproveSheet(r),
                      onReject: () {
                        context.read<AdminBloc>().add(
                          RejectRegistrationRequestEvent(
                            studentId: r.studentId,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'قبول يدوي',
                  onPressed: () => context.push(AppRoutes.adminAdmit),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RegistrationRequestEntity request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () =>
            context.push(AppRoutes.adminStudentProfile(request.studentId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: request.profileImageUrl != null
                      ? NetworkImage(request.profileImageUrl!)
                      : null,
                  child: request.profileImageUrl == null
                      ? Text(
                          request.name.isNotEmpty
                              ? request.name.characters.first
                              : '?',
                          style: const TextStyle(color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        request.phone ?? request.email ?? request.studentId,
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
                const AdminStatusBadge(
                  label: 'جديد',
                  color: AppColors.warning,
                  bg: Color(0xFFFFF3E0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: busy ? '…' : 'رفض',
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: busy ? '…' : 'قبول وتعيين',
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
