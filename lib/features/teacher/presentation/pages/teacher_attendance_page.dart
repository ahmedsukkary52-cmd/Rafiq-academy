import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';

class TeacherAttendancePage extends StatefulWidget {
  final String halaqaId;

  const TeacherAttendancePage({super.key, required this.halaqaId});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  DateTime _selectedDate = DateTime.now();

  /// Explicit selections only. Missing key / null = not selected (never default present).
  final Map<String, AttendanceStatus> _attendanceMap = {};

  /// After first successful students + day-attendance load, keep the shell visible
  /// during save/reload instead of flashing a full-page loader.
  bool _shellReady = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    _loadAttendance();
  }

  void _loadAttendance() {
    context.read<TeacherBloc>().add(
      LoadHalaqaAttendanceEvent(halaqaId: widget.halaqaId, date: _selectedDate),
    );
  }

  void _retryAll() {
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
    _loadAttendance();
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime get _minDate => _today.subtract(const Duration(days: 30));

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void _changeDate(DateTime date) {
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.attendanceSubmissionStatus == SubmissionStatus.submitting) {
      return;
    }
    final next = _normalize(date);
    if (next.isBefore(_minDate) || next.isAfter(_today)) return;
    setState(() {
      _selectedDate = next;
      _attendanceMap.clear();
    });
    _loadAttendance();
  }

  void _syncMapFromRecords(List<AttendanceRecordEntity> records) {
    _attendanceMap.clear();
    for (final record in records) {
      _attendanceMap[record.studentId] = record.status;
    }
  }

  bool _allStudentsSelected(List<HalaqaStudentSummaryEntity> students) {
    if (students.isEmpty) return false;
    return students.every((s) => _attendanceMap.containsKey(s.uid));
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TeacherBloc, TeacherState>(
          listenWhen: (prev, curr) =>
              prev.attendanceSubmissionStatus !=
              curr.attendanceSubmissionStatus,
          listener: (context, state) {
            if (state.attendanceSubmissionStatus == SubmissionStatus.success) {
              if (state.attendanceEventsUnpublished) {
                AppSnackBar.showInfo(
                  context,
                  'تم حفظ الحضور، لكن تعذّر نشر تحديثات الغياب',
                );
              } else {
                AppSnackBar.showSuccess(context, 'تم حفظ الحضور بنجاح');
              }
              context.read<TeacherBloc>().add(
                const ResetAttendanceSubmissionEvent(),
              );
            } else if (state.attendanceSubmissionStatus ==
                SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.attendanceSubmissionError ?? 'فشل حفظ الحضور',
              );
              context.read<TeacherBloc>().add(
                const ResetAttendanceSubmissionEvent(),
              );
            }
          },
        ),
        BlocListener<TeacherBloc, TeacherState>(
          listenWhen: (prev, curr) =>
              curr.dayAttendanceStatus == SectionStatus.loaded &&
              (prev.dayAttendanceStatus != SectionStatus.loaded ||
                  prev.dayAttendance != curr.dayAttendance ||
                  prev.dayAttendanceDate != curr.dayAttendanceDate),
          listener: (context, state) {
            final loadedDay = state.dayAttendanceDate;
            if (loadedDay == null ||
                loadedDay.year != _selectedDate.year ||
                loadedDay.month != _selectedDate.month ||
                loadedDay.day != _selectedDate.day) {
              return;
            }
            setState(() {
              _syncMapFromRecords(state.dayAttendance);
              if (state.studentsStatus == SectionStatus.loaded) {
                _shellReady = true;
              }
            });
          },
        ),
        BlocListener<TeacherBloc, TeacherState>(
          listenWhen: (prev, curr) =>
              curr.studentsStatus == SectionStatus.loaded &&
              curr.dayAttendanceStatus == SectionStatus.loaded &&
              prev.studentsStatus != SectionStatus.loaded,
          listener: (context, state) {
            setState(() => _shellReady = true);
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الحضور والغياب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed:
                  context
                          .watch<TeacherBloc>()
                          .state
                          .attendanceSubmissionStatus ==
                      SubmissionStatus.submitting
                  ? null
                  : _pickDate,
            ),
          ],
        ),
        body: BlocBuilder<TeacherBloc, TeacherState>(
          buildWhen: (previous, current) =>
              previous.studentsStatus != current.studentsStatus ||
              previous.students != current.students ||
              previous.studentsError != current.studentsError ||
              previous.dayAttendanceStatus != current.dayAttendanceStatus ||
              previous.dayAttendance != current.dayAttendance ||
              previous.dayAttendanceDate != current.dayAttendanceDate ||
              previous.dayAttendanceError != current.dayAttendanceError ||
              previous.attendanceSubmissionStatus !=
                  current.attendanceSubmissionStatus,
          builder: (context, state) {
            final studentsLoading =
                state.studentsStatus == SectionStatus.loading ||
                state.studentsStatus == SectionStatus.initial;
            final attendanceLoading =
                state.dayAttendanceStatus == SectionStatus.loading ||
                state.dayAttendanceStatus == SectionStatus.initial;

            if (!_shellReady && (studentsLoading || attendanceLoading)) {
              return const AppLoadingWidget();
            }

            if (state.studentsStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.studentsError ?? 'حدث خطأ',
                onRetry: _retryAll,
              );
            }

            if (state.dayAttendanceStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.dayAttendanceError ?? 'حدث خطأ',
                onRetry: _loadAttendance,
              );
            }

            final students = state.students;
            final isRefreshingAttendance = _shellReady && attendanceLoading;
            final isSaving =
                state.attendanceSubmissionStatus == SubmissionStatus.submitting;
            final dayMatchesSelection = _isSameDay(
              state.dayAttendanceDate,
              _selectedDate,
            );
            final canSave =
                students.isNotEmpty &&
                _allStudentsSelected(students) &&
                !isSaving &&
                !isRefreshingAttendance &&
                dayMatchesSelection &&
                state.dayAttendanceStatus == SectionStatus.loaded;

            final presentCount = students
                .where((s) => _attendanceMap[s.uid] == AttendanceStatus.present)
                .length;
            final absentCount = students
                .where((s) => _attendanceMap[s.uid] == AttendanceStatus.absent)
                .length;
            final lateCount = students
                .where((s) => _attendanceMap[s.uid] == AttendanceStatus.late)
                .length;
            final canWrite = TeacherWorkflowOwnership.canExecute(context);

            return Column(
              children: [
                if (!canWrite)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.paddingS,
                      AppSizes.paddingM,
                      0,
                    ),
                    child: Text(
                      'عرض إشرافي — التنفيذ ملك معلم الحلقة فقط',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                _DateNavigator(
                  date: _selectedDate,
                  onPrev:
                      !isSaving && _normalize(_selectedDate).isAfter(_minDate)
                      ? () => _changeDate(
                          _selectedDate.subtract(const Duration(days: 1)),
                        )
                      : null,
                  onNext:
                      !isSaving && _normalize(_selectedDate).isBefore(_today)
                      ? () => _changeDate(
                          _selectedDate.add(const Duration(days: 1)),
                        )
                      : null,
                ),
                if (isRefreshingAttendance)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                  ),
                _AttendanceSummaryRow(
                  present: presentCount,
                  absent: absentCount,
                  late: lateCount,
                ),
                Expanded(
                  child: students.isEmpty
                      ? const Center(
                          child: Text(
                            'لا يوجد طلاب في هذه الحلقة',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingM,
                          ),
                          itemCount: students.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, i) {
                            final student = students[i];
                            return _StudentAttendanceRow(
                              student: student,
                              status: _attendanceMap[student.uid],
                              onChanged: canWrite
                                  ? (status) => setState(
                                      () =>
                                          _attendanceMap[student.uid] = status,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                if (canWrite)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.paddingM,
                      AppSizes.paddingM,
                      MediaQuery.of(context).padding.bottom + AppSizes.paddingM,
                    ),
                    child: AppButton(
                      label: 'حفظ الحضور',
                      leading: const Icon(Icons.check_rounded, size: 20),
                      isLoading: isSaving,
                      onPressed: canSave ? _saveAttendance : null,
                    ),
                  )
                else
                  SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom +
                        AppSizes.paddingM,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _saveAttendance() {
    if (!TeacherWorkflowOwnership.canExecute(context)) {
      AppSnackBar.showInfo(
        context,
        'حفظ الحضور ملك معلم الحلقة — الإشراف للتوجيه فقط',
      );
      return;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لحفظ الحضور');
      return;
    }

    final bloc = context.read<TeacherBloc>();
    final students = bloc.state.students;

    if (students.isEmpty) {
      AppSnackBar.showInfo(context, 'لا يوجد طلاب لحفظ الحضور');
      return;
    }

    if (!_allStudentsSelected(students)) {
      AppSnackBar.showInfo(
        context,
        'يرجى تحديد حالة الحضور لجميع الطلاب قبل الحفظ',
      );
      return;
    }

    final records = students
        .map(
          (s) => AttendanceRecordEntity(
            id: '',
            studentId: s.uid,
            studentName: s.name,
            halaqaId: widget.halaqaId,
            date: _selectedDate,
            status: _attendanceMap[s.uid]!,
            recordedBy: authState.user.uid,
          ),
        )
        .toList();

    bloc.add(SaveDayAttendanceEvent(records));
  }

  Future<void> _pickDate() async {
    if (context.read<TeacherBloc>().state.attendanceSubmissionStatus ==
        SubmissionStatus.submitting) {
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _normalize(_selectedDate),
      firstDate: _minDate,
      lastDate: _today,
    );
    if (picked != null) _changeDate(picked);
  }
}

class _DateNavigator extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _DateNavigator({
    required this.date,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      '',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onNext,
          ),
          Text(
            '${weekdays[date.weekday]} ${date.day} ${months[date.month]} ${date.year}',
            style: AppTextStyles.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onPrev,
          ),
        ],
      ),
    );
  }
}

class _AttendanceSummaryRow extends StatelessWidget {
  final int present;
  final int absent;
  final int late;

  const _AttendanceSummaryRow({
    required this.present,
    required this.absent,
    required this.late,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: 8,
      ),
      child: Row(
        children: [
          _CounterBadge(
            value: late,
            label: 'متأخر',
            color: AppColors.secondaryBg,
            textColor: AppColors.secondary,
          ),
          const SizedBox(width: 8),
          _CounterBadge(
            value: absent,
            label: 'غائب',
            color: const Color(0xFFFFEBEE),
            textColor: AppColors.error,
          ),
          const SizedBox(width: 8),
          _CounterBadge(
            value: present,
            label: 'حاضر',
            color: const Color(0xFFE8F5E9),
            textColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color textColor;

  const _CounterBadge({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: AppTextStyles.headlineMedium.copyWith(color: textColor),
            ),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceRow extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;
  final AttendanceStatus? status;
  final void Function(AttendanceStatus)? onChanged;

  const _StudentAttendanceRow({
    required this.student,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Row(
            children: [
              _AttendanceButton(
                label: '!',
                isActive: status == AttendanceStatus.late,
                activeColor: AppColors.secondary,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(AttendanceStatus.late),
              ),
              const SizedBox(width: 6),
              _AttendanceButton(
                label: '✗',
                isActive: status == AttendanceStatus.absent,
                activeColor: AppColors.error,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(AttendanceStatus.absent),
              ),
              const SizedBox(width: 6),
              _AttendanceButton(
                label: '✓',
                isActive: status == AttendanceStatus.present,
                activeColor: AppColors.success,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(AttendanceStatus.present),
              ),
            ],
          ),
          const Spacer(),
          Text(student.name, style: AppTextStyles.titleMedium),
          const SizedBox(width: 12),
          UserAvatar(name: student.name, size: AppSizes.avatarS),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _AttendanceButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive ? activeColor : activeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : activeColor,
            ),
          ),
        ),
      ),
    );
  }
}
