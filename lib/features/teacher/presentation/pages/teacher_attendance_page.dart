import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/attendance_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';
import '../widgets/teacher_home_figma_cards.dart';

/// Teacher Attendance — Figma 1:914 + session-scoped Firestore via [TeacherBloc].
class TeacherAttendancePage extends StatefulWidget {
  final String halaqaId;

  /// When true, render body only (no route AppBar) for Class Details tabs.
  final bool embedded;

  const TeacherAttendancePage({
    super.key,
    required this.halaqaId,
    this.embedded = false,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final _attendanceService = sl<AttendanceService>();

  late DateTime _selectedDate;

  /// Local draft statuses keyed by student uid (null = unmarked).
  final Map<String, AttendanceStatus?> _draft = {};

  /// Tracks which attendance load we last hydrated from.
  DateTime? _hydratedAttendanceDate;
  int _hydratedAttendanceHash = 0;

  /// After a successful save, ignore dirty until the next hydrate (or edit).
  bool _suppressDirtyUntilHydrate = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = AttendancePolicy.dayStart(DateTime.now());
    final bloc = context.read<TeacherBloc>();
    _ensureHalaqatLoaded(bloc);
    bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapSessionDate(bloc);
    });
  }

  void _ensureHalaqatLoaded(TeacherBloc bloc) {
    if (_halaqaFromState(bloc.state) != null) return;
    final auth = context
        .read<AuthBloc>()
        .state;
    if (auth is! AuthAuthenticated) return;
    bloc.add(LoadTeacherHalaqatEvent(auth.user.uid));
  }

  void _bootstrapSessionDate(TeacherBloc bloc) {
    final halaqa = _halaqaFromState(bloc.state);
    final open = _attendanceService.openRegister(
      halaqaId: widget.halaqaId,
      halaqa: halaqa,
      existingRecords: const [],
    );
    setState(() => _selectedDate = open.sessionDate);
    bloc.add(
      LoadHalaqaAttendanceEvent(
        halaqaId: widget.halaqaId,
        date: open.sessionDate,
      ),
    );
  }

  HalaqaEntity? _halaqaFromState(TeacherState state) {
    for (final h in state.halaqat) {
      if (h.id == widget.halaqaId) return h;
    }
    return null;
  }

  AttendanceOpenModel _openModel(TeacherState state) {
    return _attendanceService.openRegister(
      halaqaId: widget.halaqaId,
      halaqa: _halaqaFromState(state),
      existingRecords: state.dayAttendance,
      sessionDate: _selectedDate,
    );
  }

  bool _hydrateDraftIfNeeded(TeacherState state, AttendanceOpenModel open) {
    final loaded =
        state.dayAttendanceStatus == SectionStatus.loaded &&
        state.dayAttendanceDate != null &&
        AttendancePolicy.isSameCalendarDay(
          state.dayAttendanceDate!,
          open.sessionDate,
        );
    if (!loaded) return false;

    // Do not clobber in-progress edits while a save round-trip reloads.
    if (state.attendanceSubmissionStatus == SubmissionStatus.submitting ||
        state.attendanceSubmissionStatus == SubmissionStatus.success) {
      return false;
    }

    final hash = Object.hashAll(
      state.dayAttendance.map(
        (r) => Object.hash(r.id, r.studentId, r.status, r.sessionId),
      ),
    );
    final studentsHash = Object.hashAll(state.students.map((s) => s.uid));
    final combined = Object.hash(hash, studentsHash);
    if (_hydratedAttendanceDate != null &&
        AttendancePolicy.isSameCalendarDay(
          _hydratedAttendanceDate!,
          open.sessionDate,
        ) &&
        _hydratedAttendanceHash == combined) {
      return false;
    }

    _hydratedAttendanceDate = open.sessionDate;
    _hydratedAttendanceHash = combined;
    _suppressDirtyUntilHydrate = false;
    _draft
      ..clear()
      ..addAll({
        for (final s in state.students)
          if (s.uid.trim().isNotEmpty) s.uid: open.existingByStudentId[s.uid],
      });
    return true;
  }

  void _loadDate(DateTime date) {
    final day = AttendancePolicy.dayStart(date);
    setState(() {
      _selectedDate = day;
      _draft.clear();
      _hydratedAttendanceDate = null;
      _hydratedAttendanceHash = 0;
    });
    context.read<TeacherBloc>().add(
      LoadHalaqaAttendanceEvent(halaqaId: widget.halaqaId, date: day),
    );
  }

  void _shiftDate(int days, {required bool locked}) {
    if (locked) return;
    _loadDate(_selectedDate.add(Duration(days: days)));
  }

  Future<void> _pickDate({required bool locked}) async {
    if (locked) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    _loadDate(picked);
  }

  void _setStatus(String id, AttendanceStatus status, {required bool canEdit}) {
    if (!canEdit) return;
    setState(() {
      _suppressDirtyUntilHydrate = false;
      _draft[id] = status;
    });
  }

  bool _isRegisterComplete(List<HalaqaStudentSummaryEntity> students) {
    if (students.isEmpty) return false;
    return _attendanceService.isRegisterComplete(
      rosterStudentIds: students.map((s) => s.uid),
      markedStudentIds: _draft.entries
          .where((e) => e.value != null)
          .map((e) => e.key),
    );
  }

  bool _hasUnsavedChanges(List<HalaqaStudentSummaryEntity> students,
      AttendanceOpenModel open,) {
    if (_suppressDirtyUntilHydrate) return false;
    return _attendanceService.hasUnsavedChanges(
      rosterStudentIds: students.map((s) => s.uid),
      draft: _draft,
      saved: open.existingByStudentId,
    );
  }

  String? _teacherUid() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) return auth.user.uid;
    return null;
  }

  void _onSave(TeacherState state, AttendanceOpenModel open) {
    if (!TeacherWorkflowOwnership.canExecute(context)) return;
    if (state.attendanceSubmissionStatus == SubmissionStatus.submitting) {
      return;
    }
    final teacherId = _teacherUid();
    if (teacherId == null || teacherId.isEmpty) {
      AppSnackBar.showError(context, 'تعذر تحديد هوية المعلم');
      return;
    }

    final marks = <AttendanceDraftMark>[];
    for (final s in state.students) {
      final status = _draft[s.uid];
      if (status == null) continue;
      marks.add(
        AttendanceDraftMark(
          studentId: s.uid,
          studentName: s.name,
          status: status,
        ),
      );
    }

    final result = _attendanceService.planSessionSave(
      open: open,
      recordedBy: teacherId,
      rosterStudentIds: state.students.map((s) => s.uid),
      marks: marks,
      existingRecords: state.dayAttendance,
    );
    if (!result.isReady) {
      final message = switch (result.blockReason) {
        AttendanceSaveBlockReason.sessionClosed =>
          'انتهت جلسة هذا اليوم — التعديل غير متاح',
        AttendanceSaveBlockReason.registerIncomplete =>
          'سجّل حضور جميع الطلاب قبل الحفظ',
        AttendanceSaveBlockReason.nothingToSave =>
          'سجّل حضور جميع الطلاب قبل الحفظ',
        AttendanceSaveBlockReason.missingSessionId =>
          'تعذر تحديد جلسة الحضور',
        null => 'تعذر حفظ الحضور',
      };
      AppSnackBar.showError(context, message);
      return;
    }

    context.read<TeacherBloc>().add(
      SaveDayAttendanceEvent(result.plan!.records),
    );
  }

  int _count(AttendanceStatus status) =>
      _draft.values.where((s) => s == status).length;

  void _onSubmissionStatusChanged(TeacherState state) {
    if (state.attendanceSubmissionStatus == SubmissionStatus.success) {
      AppSnackBar.showSuccess(context, 'تم حفظ الحضور');
      if (state.attendanceEventsUnpublished) {
        AppSnackBar.showInfo(
          context,
          'الحضور محفوظ — تعذر إرسال إشعار الغياب',
        );
      }
      setState(() => _suppressDirtyUntilHydrate = true);
      context.read<TeacherBloc>().add(const ResetAttendanceSubmissionEvent());
    } else if (state.attendanceSubmissionStatus == SubmissionStatus.error &&
        state.attendanceSubmissionError != null) {
      AppSnackBar.showError(context, state.attendanceSubmissionError!);
      context.read<TeacherBloc>().add(const ResetAttendanceSubmissionEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = TeacherWorkflowOwnership.canExecute(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MultiBlocListener(
        listeners: [
          // Snackbar exactly once per submission status transition.
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (prev, curr) =>
            prev.attendanceSubmissionStatus !=
                curr.attendanceSubmissionStatus,
            listener: (context, state) => _onSubmissionStatusChanged(state),
          ),
          // Hydrate draft when roster / day marks load (not on save success).
          BlocListener<TeacherBloc, TeacherState>(
            listenWhen: (prev, curr) =>
            prev.dayAttendance != curr.dayAttendance ||
                prev.dayAttendanceStatus != curr.dayAttendanceStatus ||
                prev.students != curr.students ||
                prev.studentsStatus != curr.studentsStatus ||
                prev.halaqat != curr.halaqat,
            listener: (context, state) {
              final open = _openModel(state);
              _hydrateDraftIfNeeded(state, open);
              // Rebuild so canEdit picks up schedule endAt once halaqa loads.
              if (mounted) setState(() {});
            },
          ),
        ],
        child: BlocBuilder<TeacherBloc, TeacherState>(
          buildWhen: (prev, curr) =>
          prev.dayAttendance != curr.dayAttendance ||
              prev.dayAttendanceStatus != curr.dayAttendanceStatus ||
              prev.dayAttendanceError != curr.dayAttendanceError ||
              prev.dayAttendanceDate != curr.dayAttendanceDate ||
              prev.students != curr.students ||
              prev.studentsStatus != curr.studentsStatus ||
              prev.studentsError != curr.studentsError ||
              prev.studentsHalaqaId != curr.studentsHalaqaId ||
              prev.halaqat != curr.halaqat ||
              prev.attendanceSubmissionStatus !=
                  curr.attendanceSubmissionStatus,
          builder: (context, state) {
            final open = _openModel(state);
            final submitting =
                state.attendanceSubmissionStatus ==
                    SubmissionStatus.submitting;
            final dateLocked = submitting;
            final canEdit = canWrite && open.canEdit && !submitting;
            final studentsForHalaqa =
            state.studentsHalaqaId == widget.halaqaId
                ? state.students
                : const <HalaqaStudentSummaryEntity>[];
            final dirty = _hasUnsavedChanges(studentsForHalaqa, open);
            final complete = _isRegisterComplete(studentsForHalaqa);
            final saveEnabled =
                canEdit && complete && dirty && !submitting && canWrite;

            final body = _buildBody(
              context: context,
              state: state,
              open: open,
              students: studentsForHalaqa,
              canEdit: canEdit,
              dateLocked: dateLocked,
              submitting: submitting,
              canWrite: canWrite,
              saveEnabled: saveEnabled,
            );

            return Scaffold(
              backgroundColor: AppColors.background,
              body: widget.embedded
                  ? Column(
                children: [
                  _EmbeddedHeader(
                    onCalendar: () => _pickDate(locked: dateLocked),
                    canEdit: canEdit,
                  ),
                  Expanded(child: body),
                ],
              )
                  : Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 340,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _AttendanceHeader(
                        onBack: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/teacher');
                          }
                        },
                        onCalendar: () =>
                            _pickDate(locked: dateLocked),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                AppSizes.radiusXL,
                              ),
                              topRight: Radius.circular(
                                AppSizes.radiusXL,
                              ),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required TeacherState state,
    required AttendanceOpenModel open,
    required List<HalaqaStudentSummaryEntity> students,
    required bool canEdit,
    required bool dateLocked,
    required bool submitting,
    required bool canWrite,
    required bool saveEnabled,
  }) {
    final studentsLoading =
        (state.studentsStatus == SectionStatus.loading ||
            state.studentsStatus == SectionStatus.initial) &&
        students.isEmpty;
    final attendanceLoading =
        state.dayAttendanceStatus == SectionStatus.loading;
    final studentsError = state.studentsStatus == SectionStatus.error
        ? state.studentsError
        : null;
    final attendanceError = state.dayAttendanceStatus == SectionStatus.error
        ? state.dayAttendanceError
        : null;

    if (studentsError != null) {
      return AppErrorWidget(
        message: studentsError,
        onRetry: () => context.read<TeacherBloc>().add(
          LoadHalaqaStudentsEvent(widget.halaqaId),
        ),
      );
    }
    if (attendanceError != null) {
      return AppErrorWidget(
        message: attendanceError,
        onRetry: () => context.read<TeacherBloc>().add(
          LoadHalaqaAttendanceEvent(
            halaqaId: widget.halaqaId,
            date: open.sessionDate,
          ),
        ),
      );
    }
    if (studentsLoading || (attendanceLoading && students.isEmpty)) {
      return const AppLoadingWidget();
    }
    if (students.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد طلاب في هذه الحلقة',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _DateCard(
            date: open.sessionDate,
            onPrev: () => _shiftDate(-1, locked: dateLocked),
            onNext: () => _shiftDate(1, locked: dateLocked),
          ),
        ),
        if (!open.canEdit) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'انتهت الجلسة — الحضور للعرض فقط',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SummaryRow(
            present: _count(AttendanceStatus.present),
            absent: _count(AttendanceStatus.absent),
            late: _count(AttendanceStatus.late),
            excused: _count(AttendanceStatus.excused),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: attendanceLoading
                ? const AppLoadingWidget()
                : _RegisterCard(
                    students: [
                      for (final s in students)
                        _RegisterStudent(
                          id: s.uid,
                          name: s.name,
                          status: _draft[s.uid],
                        ),
                    ],
                    onStatusChanged: (id, status) =>
                        _setStatus(id, status, canEdit: canEdit),
                  ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: AppButton(
            label: submitting ? 'جارٍ الحفظ...' : 'حفظ الحضور',
            isLoading: submitting,
            leading: submitting
                ? null
                : const Icon(
                    Icons.check_rounded,
                    size: AppSizes.iconM,
                    color: AppColors.onPrimary,
                  ),
            onPressed: saveEnabled ? () => _onSave(state, open) : null,
          ),
        ),
      ],
    );
  }
}

class _RegisterStudent {
  final String id;
  final String name;
  final AttendanceStatus? status;

  const _RegisterStudent({
    required this.id,
    required this.name,
    required this.status,
  });
}

// ── Headers ───────────────────────────────────────────────────────────────────

class _AttendanceHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onCalendar;

  const _AttendanceHeader({
    required this.onBack,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 40),
      child: Row(
        children: [
          _HeaderCircleButton(
            icon: Icons.chevron_right_rounded,
            onTap: onBack,
          ),
          Expanded(
            child: Text(
              'الحضور والغياب',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _HeaderCircleButton(
            icon: Icons.calendar_today_outlined,
            onTap: onCalendar,
          ),
        ],
      ),
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  final VoidCallback onCalendar;
  final bool canEdit;

  const _EmbeddedHeader({
    required this.onCalendar,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'الحضور والغياب',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: AppColors.primaryLight,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onCalendar,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primaryDark,
                  size: AppSizes.iconL,
                ),
              ),
            ),
          ),
          if (!canEdit) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.lock_outline,
              size: AppSizes.iconM,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimaryOverlay,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.onPrimary, size: AppSizes.iconL),
        ),
      ),
    );
  }
}

// ── Date card ─────────────────────────────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateCard({
    required this.date,
    required this.onPrev,
    required this.onNext,
  });

  static const _weekdays = [
    '',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.fromDate(date);
    final dayNum = teacherHomeEasternDigits('${hijri.hDay}');
    final label =
        '${_weekdays[date.weekday]} $dayNum ${hijri.getLongMonthName()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.textSecondary,
            iconSize: AppSizes.iconL,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.textSecondary,
            iconSize: AppSizes.iconL,
          ),
        ],
      ),
    );
  }
}

// ── Summary chips: present / absent / late / excused ───────────────────────────

class _SummaryRow extends StatelessWidget {
  final int present;
  final int absent;
  final int late;
  final int excused;

  const _SummaryRow({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
  });

  @override
  Widget build(BuildContext context) {
    // Class Details stats gap = 10; RTL: Present rightmost.
    return Row(
      children: [
        _SummaryChip(
          count: present,
          label: 'حاضر',
          background: AppColors.successBg,
          foreground: AppColors.success,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          count: absent,
          label: 'غائب',
          background: AppColors.error.withValues(alpha: 0.12),
          foreground: AppColors.error,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          count: late,
          label: 'متأخر',
          background: AppColors.secondaryBg,
          foreground: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          count: excused,
          label: 'معذور',
          background: AppColors.primaryLight,
          foreground: AppColors.primaryDark,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color background;
  final Color foreground;

  const _SummaryChip({
    required this.count,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          children: [
            Text(
              teacherHomeEasternDigits('$count'),
              style: AppTextStyles.headlineMedium.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Register table ────────────────────────────────────────────────────────────

class _RegisterCard extends StatelessWidget {
  final List<_RegisterStudent> students;
  final void Function(String id, AttendanceStatus status) onStatusChanged;

  const _RegisterCard({
    required this.students,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _RegisterHeader(),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, i) {
                final student = students[i];
                return _StudentRow(
                  student: student,
                  avatarColor: _avatarColor(i),
                  onStatusChanged: (status) =>
                      onStatusChanged(student.id, status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(int index) {
    const palette = [
      AppColors.primaryLight,
      AppColors.secondaryBg,
      AppColors.successBg,
      AppColors.messagesBg,
      AppColors.info,
    ];
    final base = palette[index % palette.length];
    if (base == AppColors.info) {
      return AppColors.info.withValues(alpha: 0.18);
    }
    return base;
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    // RTL visual order (right → left): الطالب · متأخر · غائب · حاضر · معذور
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'الطالب',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Text(
              'متأخر',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Text(
              'غائب',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Text(
              'حاضر',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Text(
              'معذور',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _statusColumnWidth = 44;

class _StudentRow extends StatelessWidget {
  final _RegisterStudent student;
  final Color avatarColor;
  final ValueChanged<AttendanceStatus> onStatusChanged;

  const _StudentRow({
    required this.student,
    required this.avatarColor,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = student.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCodes(trimmed.runes.take(1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Center(
              child: _StatusToggle(
                selected: student.status == AttendanceStatus.late,
                color: AppColors.secondary,
                icon: Icons.priority_high_rounded,
                onTap: () => onStatusChanged(AttendanceStatus.late),
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Center(
              child: _StatusToggle(
                selected: student.status == AttendanceStatus.absent,
                color: AppColors.error,
                icon: Icons.close_rounded,
                onTap: () => onStatusChanged(AttendanceStatus.absent),
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Center(
              child: _StatusToggle(
                selected: student.status == AttendanceStatus.present,
                color: AppColors.success,
                icon: Icons.check_rounded,
                onTap: () => onStatusChanged(AttendanceStatus.present),
              ),
            ),
          ),
          SizedBox(
            width: _statusColumnWidth,
            child: Center(
              child: _StatusToggle(
                selected: student.status == AttendanceStatus.excused,
                color: AppColors.primaryDark,
                icon: Icons.verified_outlined,
                onTap: () => onStatusChanged(AttendanceStatus.excused),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusToggle({
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSizes.radiusS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: AppSizes.iconM,
            color: selected ? AppColors.onPrimary : color,
          ),
        ),
      ),
    );
  }
}
