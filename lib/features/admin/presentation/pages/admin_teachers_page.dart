import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadAllTeachersEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadAllTeachersEvent());
    await bloc.stream.firstWhere(
      (s) => s.teachersStatus != SectionStatus.loading,
    );
  }

  Future<void> _editRating(TeacherManagementEntity teacher) async {
    final ctrl = TextEditingController(
      text: teacher.performanceRating?.toStringAsFixed(1) ?? '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم ${teacher.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0.0 — 5.0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v < 0 || v > 5) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || result == null) return;
    context.read<AdminBloc>().add(
      UpdateTeacherPerformanceEvent(teacherId: teacher.uid, rating: result),
    );
  }

  Future<void> _editQuota(TeacherManagementEntity teacher) async {
    final ctrl = TextEditingController(text: '${teacher.weeklyQuota}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('نصاب ${teacher.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'حصص أسبوعياً'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v == null || v < 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || result == null) return;
    context.read<AdminBloc>().add(
      UpdateTeacherQuotaEvent(teacherId: teacher.uid, weeklyQuota: result),
    );
  }

  Future<void> _toggleAccount(TeacherManagementEntity teacher) async {
    final activate = !teacher.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? 'تفعيل الحساب' : 'تعطيل الحساب'),
        content: Text(
          activate
              ? 'هل تريد تفعيل حساب ${teacher.name}؟'
              : 'هل تريد تعطيل حساب ${teacher.name}؟ لن يتمكن من تسجيل الدخول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(activate ? 'تفعيل' : 'تعطيل'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    context.read<AdminBloc>().add(
      ToggleAccountStatusEvent(uid: teacher.uid, isActive: activate),
    );
  }

  Future<void> _showActivity(TeacherManagementEntity teacher) async {
    final bloc = context.read<AdminBloc>();
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    bloc.add(
      LoadTeacherActivityLogEvent(teacherId: teacher.uid, from: from, to: to),
    );

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return BlocProvider.value(
          value: bloc,
          child: BlocBuilder<AdminBloc, AdminState>(
            buildWhen: (p, c) =>
                p.teacherActivityStatus != c.teacherActivityStatus ||
                p.teacherActivity != c.teacherActivity,
            builder: (context, state) {
              if (state.teacherActivityStatus == SectionStatus.loading) {
                return const AdminActivityLogSkeleton();
              }
              if (state.teacherActivityStatus == SectionStatus.error) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppErrorWidget(
                    message: state.teacherActivityError ?? 'تعذر التحميل',
                    onRetry: () {
                      bloc.add(
                        LoadTeacherActivityLogEvent(
                          teacherId: teacher.uid,
                          from: from,
                          to: to,
                        ),
                      );
                    },
                  ),
                );
              }

              final activity = state.teacherActivity;
              final dates = activity?.activeDates ?? const <DateTime>[];
              dates.sort((a, b) => b.compareTo(a));

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.paddingOf(ctx).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'نشاط ${teacher.name}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'آخر 30 يوماً — ${dates.length} يوم نشاط',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (dates.isEmpty)
                      const AdminPlaceholderCard(
                        icon: Icons.event_busy_outlined,
                        title: 'لا نشاط مسجل',
                        message:
                            'لم يُسجَّل حضور بواسطة هذا المعلم خلال الفترة المحددة.',
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(ctx).height * 0.4,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: dates.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = dates[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                              title: Text(
                                '${d.day}/${d.month}/${d.year}',
                                style: AppTextStyles.bodyMedium,
                              ),
                              subtitle: const Text('تسجيل حضور'),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) =>
          p.updatePerformanceStatus != c.updatePerformanceStatus ||
          p.updateQuotaStatus != c.updateQuotaStatus ||
          p.toggleAccountStatus != c.toggleAccountStatus,
      listener: (context, state) {
        if (state.updatePerformanceStatus == SubmissionStatus.success ||
            state.updateQuotaStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم التحديث');
          context.read<AdminBloc>().add(
            const ResetUpdateTeacherPerformanceEvent(),
          );
          context.read<AdminBloc>().add(const ResetUpdateTeacherQuotaEvent());
        } else if (state.updatePerformanceStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.updatePerformanceError ?? 'تعذر التحديث',
          );
          context.read<AdminBloc>().add(
            const ResetUpdateTeacherPerformanceEvent(),
          );
        } else if (state.updateQuotaStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.updateQuotaError ?? 'تعذر التحديث',
          );
          context.read<AdminBloc>().add(const ResetUpdateTeacherQuotaEvent());
        } else if (state.toggleAccountStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم تحديث حالة الحساب');
          context.read<AdminBloc>().add(const ResetToggleAccountEvent());
          context.read<AdminBloc>().add(const LoadAllTeachersEvent());
        } else if (state.toggleAccountStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.toggleAccountError ?? 'تعذر تحديث الحساب',
          );
          context.read<AdminBloc>().add(const ResetToggleAccountEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'إدارة المعلمين',
        body: BlocBuilder<AdminBloc, AdminState>(
          buildWhen: (p, c) =>
              p.teachersStatus != c.teachersStatus ||
              p.teachers != c.teachers ||
              p.toggleAccountStatus != c.toggleAccountStatus,
          builder: (context, state) {
            if (state.teachersStatus == SectionStatus.loading &&
                state.teachers.isEmpty) {
              return const AdminTeachersListSkeleton();
            }
            if (state.teachersStatus == SectionStatus.error &&
                state.teachers.isEmpty) {
              return AppErrorWidget(
                message: state.teachersError ?? 'تعذر التحميل',
                onRetry: _refresh,
              );
            }

            if (state.teachers.isEmpty) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    AdminPlaceholderCard(
                      icon: Icons.school_outlined,
                      title: 'لا معلمون',
                      message: 'لم يُسجَّل أي معلم في الأكاديمية بعد.',
                    ),
                  ],
                ),
              );
            }

            final toggling =
                state.toggleAccountStatus == SubmissionStatus.submitting;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: state.teachers.length,
                itemBuilder: (context, i) {
                  final t = state.teachers[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TeacherCard(
                      teacher: t,
                      busy: toggling,
                      onEditRating: () => _editRating(t),
                      onEditQuota: () => _editQuota(t),
                      onToggleAccount: () => _toggleAccount(t),
                      onShowActivity: () => _showActivity(t),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherManagementEntity teacher;
  final bool busy;
  final VoidCallback onEditRating;
  final VoidCallback onEditQuota;
  final VoidCallback onToggleAccount;
  final VoidCallback onShowActivity;

  const _TeacherCard({
    required this.teacher,
    required this.busy,
    required this.onEditRating,
    required this.onEditQuota,
    required this.onToggleAccount,
    required this.onShowActivity,
  });

  @override
  Widget build(BuildContext context) {
    final initial = teacher.name.isNotEmpty
        ? teacher.name.characters.first
        : 'م';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                backgroundImage: teacher.profileImageUrl != null
                    ? NetworkImage(teacher.profileImageUrl!)
                    : null,
                child: teacher.profileImageUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${teacher.halaqatIds.length} حلقة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AdminStatusBadge(
                label: teacher.isActive ? 'نشط' : 'معطّل',
                color: teacher.isActive ? AppColors.success : AppColors.error,
                bg: (teacher.isActive ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onEditRating,
                  child: Text(
                    'تقييم: ${teacher.performanceRating?.toStringAsFixed(1) ?? '—'}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onEditQuota,
                  child: Text('نصاب: ${teacher.weeklyQuota}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onShowActivity,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('النشاط'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onToggleAccount,
                  icon: Icon(
                    teacher.isActive
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(teacher.isActive ? 'تعطيل' : 'تفعيل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
