import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/domain/absence_request_projection.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';
import '../widgets/excuses/teacher_excuses_history_skeleton.dart';

/// Resolves a display name for an استئذان row (presentation only).
String teacherAbsenceStudentTitle({
  required String studentId,
  required List<HalaqaStudentSummaryEntity> students,
}) {
  for (final student in students) {
    if (student.uid == studentId) {
      final name = student.name.trim();
      if (name.isNotEmpty) return name;
    }
  }
  return 'طالب';
}

AppStatusTone teacherAbsenceStatusTone(AbsenceRequestStatus status) =>
    switch (status) {
      AbsenceRequestStatus.pending => AppStatusTone.warning,
      AbsenceRequestStatus.approved => AppStatusTone.success,
      AbsenceRequestStatus.rejected => AppStatusTone.error,
    };

/// Teacher review of **parent** استئذان requests (W7).
///
/// Uses existing [LoadPendingAbsenceRequestsEvent] / [ReviewAbsenceRequestEvent].
/// Teacher self-excuse submit is intentionally not offered.
class TeacherExcusesPage extends StatefulWidget {
  const TeacherExcusesPage({super.key});

  @override
  State<TeacherExcusesPage> createState() => _TeacherExcusesPageState();
}

class _TeacherExcusesPageState extends State<TeacherExcusesPage> {
  String? _halaqaId;
  late DateTime _date;
  String? _reviewingRequestId;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  String? get _teacherId {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return null;
    return auth.user.uid;
  }

  void _bootstrap() {
    final teacherId = _teacherId;
    if (teacherId == null) return;
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.halaqat.isEmpty) {
      bloc.add(LoadTeacherHalaqatEvent(teacherId));
    } else {
      _ensureHalaqaSelection(bloc.state.halaqat);
      _reload();
    }
  }

  void _ensureHalaqaSelection(List<HalaqaEntity> halaqat) {
    if (halaqat.isEmpty) {
      _halaqaId = null;
      return;
    }
    final current = _halaqaId?.trim() ?? '';
    final stillValid = halaqat.any((h) => h.id == current);
    if (!stillValid) {
      setState(() => _halaqaId = halaqat.first.id);
    }
  }

  void _reload() {
    final teacherId = _teacherId;
    final halaqaId = _halaqaId?.trim();
    if (teacherId == null || halaqaId == null || halaqaId.isEmpty) return;
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(halaqaId));
    context.read<TeacherBloc>().add(
      LoadPendingAbsenceRequestsEvent(
        teacherId: teacherId,
        halaqaId: halaqaId,
        date: _date,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _reload();
  }

  void _onHalaqaChanged(String? id) {
    final next = id?.trim();
    if (next == null || next.isEmpty) return;
    setState(() => _halaqaId = next);
    _reload();
  }

  void _review(AbsenceRequestEntity request, AbsenceRequestStatus decision) {
    if (!TeacherWorkflowOwnership.canExecute(context)) return;
    final teacherId = _teacherId;
    final halaqaId = _halaqaId?.trim();
    if (teacherId == null || halaqaId == null || halaqaId.isEmpty) return;
    if (decision == AbsenceRequestStatus.pending) return;
    setState(() => _reviewingRequestId = request.id);
    context.read<TeacherBloc>().add(
      ReviewAbsenceRequestEvent(
        requestId: request.id,
        halaqaId: halaqaId,
        teacherId: teacherId,
        decision: decision,
      ),
    );
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSubpageScaffold(
      title: 'طلبات الاستئذان',
      backgroundColor: AppColors.background,
      onBack: _onBack,
      body: MultiBlocListener(
        listeners: [
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (p, c) => p.halaqatStatus != c.halaqatStatus,
            listener: (context, state) {
              if (state.halaqatStatus == SectionStatus.loaded) {
                _ensureHalaqaSelection(state.halaqat);
                _reload();
              }
            },
          ),
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (p, c) =>
                p.absenceReviewStatus != c.absenceReviewStatus ||
                p.absenceReviewError != c.absenceReviewError,
            listener: (context, state) {
              if (state.absenceReviewStatus == SubmissionStatus.error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.absenceReviewError ?? 'تعذر مراجعة الطلب',
                    ),
                  ),
                );
                context.read<TeacherBloc>().add(
                  const ResetAbsenceReviewEvent(),
                );
                setState(() => _reviewingRequestId = null);
              } else if (state.absenceReviewStatus ==
                  SubmissionStatus.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ قرار المراجعة')),
                );
                context.read<TeacherBloc>().add(
                  const ResetAbsenceReviewEvent(),
                );
                setState(() => _reviewingRequestId = null);
              }
            },
          ),
        ],
        child: BlocBuilder<TeacherBloc, TeacherState>(
          buildWhen: (p, c) =>
              p.halaqatStatus != c.halaqatStatus ||
              p.halaqat != c.halaqat ||
              p.halaqatError != c.halaqatError ||
              p.students != c.students ||
              p.pendingAbsenceRequestsStatus !=
                  c.pendingAbsenceRequestsStatus ||
              p.pendingAbsenceRequests != c.pendingAbsenceRequests ||
              p.pendingAbsenceRequestsError != c.pendingAbsenceRequestsError ||
              p.absenceReviewStatus != c.absenceReviewStatus,
          builder: (context, state) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                final teacherId = _teacherId;
                if (teacherId != null && state.halaqat.isEmpty) {
                  context.read<TeacherBloc>().add(
                    LoadTeacherHalaqatEvent(teacherId),
                  );
                } else {
                  _reload();
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    'مراجعة طلبات استئذان أولياء الأمور فقط — لا يوجد تقديم اعتذار ذاتي للمعلم.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 14),
                  _FiltersCard(
                    halaqat: state.halaqat,
                    selectedHalaqaId: _halaqaId,
                    dateLabel: formatDateDmy(_date),
                    onHalaqaChanged: _onHalaqaChanged,
                    onDateTap: _pickDate,
                    halaqatLoading:
                        state.halaqatStatus == SectionStatus.initial ||
                        state.halaqatStatus == SectionStatus.loading,
                    halaqatError: state.halaqatStatus == SectionStatus.error
                        ? (state.halaqatError ?? 'تعذر تحميل الحلقات')
                        : null,
                    onRetryHalaqat: () {
                      final teacherId = _teacherId;
                      if (teacherId == null) return;
                      context.read<TeacherBloc>().add(
                        LoadTeacherHalaqatEvent(teacherId),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _RequestsBody(
                    state: state,
                    halaqaId: _halaqaId,
                    reviewingRequestId: _reviewingRequestId,
                    reviewBusy:
                        state.absenceReviewStatus ==
                        SubmissionStatus.submitting,
                    onRetry: _reload,
                    onApprove: (r) => _review(r, AbsenceRequestStatus.approved),
                    onReject: (r) => _review(r, AbsenceRequestStatus.rejected),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final List<HalaqaEntity> halaqat;
  final String? selectedHalaqaId;
  final String dateLabel;
  final ValueChanged<String?> onHalaqaChanged;
  final VoidCallback onDateTap;
  final bool halaqatLoading;
  final String? halaqatError;
  final VoidCallback onRetryHalaqat;

  const _FiltersCard({
    required this.halaqat,
    required this.selectedHalaqaId,
    required this.dateLabel,
    required this.onHalaqaChanged,
    required this.onDateTap,
    required this.halaqatLoading,
    required this.halaqatError,
    required this.onRetryHalaqat,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (halaqatLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (halaqatError != null)
              AppErrorWidget(message: halaqatError!, onRetry: onRetryHalaqat)
            else if (halaqat.isEmpty)
              Text(
                'لا توجد حلقات مرتبطة بحسابك.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.right,
              )
            else
              DropdownButtonFormField<String>(
                value:
                    selectedHalaqaId != null &&
                        halaqat.any((h) => h.id == selectedHalaqaId)
                    ? selectedHalaqaId
                    : halaqat.first.id,
                decoration: const InputDecoration(
                  labelText: 'الحلقة',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final h in halaqat)
                    DropdownMenuItem(value: h.id, child: Text(h.name)),
                ],
                onChanged: onHalaqaChanged,
              ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اليوم',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(dateLabel, textAlign: TextAlign.right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsBody extends StatelessWidget {
  final TeacherState state;
  final String? halaqaId;
  final String? reviewingRequestId;
  final bool reviewBusy;
  final VoidCallback onRetry;
  final ValueChanged<AbsenceRequestEntity> onApprove;
  final ValueChanged<AbsenceRequestEntity> onReject;

  const _RequestsBody({
    required this.state,
    required this.halaqaId,
    required this.reviewingRequestId,
    required this.reviewBusy,
    required this.onRetry,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (halaqaId == null || halaqaId!.trim().isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'اختر حلقة أولاً',
        message: 'حدّد الحلقة والتاريخ لعرض طلبات الاستئذان المعلّقة.',
      );
    }

    final status = state.pendingAbsenceRequestsStatus;
    if (status == SectionStatus.initial || status == SectionStatus.loading) {
      return const TeacherExcusesHistorySkeleton();
    }
    if (status == SectionStatus.error) {
      return AppErrorWidget(
        message: state.pendingAbsenceRequestsError ?? 'تعذر تحميل الطلبات',
        onRetry: onRetry,
      );
    }

    final requests = state.pendingAbsenceRequests;
    if (requests.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inbox_outlined,
        title: 'لا توجد طلبات معلّقة',
        message: 'لا يوجد استئذان قيد المراجعة لهذه الحلقة في اليوم المحدد.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < requests.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ReviewRequestCard(
            request: requests[i],
            studentTitle: teacherAbsenceStudentTitle(
              studentId: requests[i].studentId,
              students: state.students,
            ),
            busy: reviewBusy && reviewingRequestId == requests[i].id,
            actionsEnabled: !reviewBusy,
            onApprove: () => onApprove(requests[i]),
            onReject: () => onReject(requests[i]),
          ),
        ],
      ],
    );
  }
}

class _ReviewRequestCard extends StatelessWidget {
  final AbsenceRequestEntity request;
  final String studentTitle;
  final bool busy;
  final bool actionsEnabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewRequestCard({
    required this.request,
    required this.studentTitle,
    required this.busy,
    required this.actionsEnabled,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final pending = request.status == AbsenceRequestStatus.pending;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    studentTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusChip(
                  label: AbsenceRequestProjection.statusLabel(request.status),
                  tone: teacherAbsenceStatusTone(request.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatDateDmy(request.date),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Text(
              request.reason,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
              textAlign: TextAlign.right,
            ),
            if (pending) ...[
              const SizedBox(height: 12),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: actionsEnabled ? onReject : null,
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: actionsEnabled ? onApprove : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                        child: const Text('قبول'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
