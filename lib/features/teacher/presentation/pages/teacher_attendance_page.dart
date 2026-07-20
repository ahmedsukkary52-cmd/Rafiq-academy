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

class TeacherAttendancePage extends StatefulWidget {
  final String halaqaId;

  const TeacherAttendancePage({super.key, required this.halaqaId});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  DateTime _selectedDate = DateTime.now();

  // تتبع حالة كل طالب محلياً قبل الحفظ
  final Map<String, AttendanceStatus> _attendanceMap = {};

  @override
  void initState() {
    super.initState();
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الحضور والغياب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: BlocBuilder<TeacherBloc, TeacherState>(
        builder: (context, state) {
          if (state.studentsStatus == SectionStatus.loading) {
            return const AppLoadingWidget();
          }
          if (state.studentsStatus == SectionStatus.error) {
            return AppErrorWidget(message: state.studentsError ?? 'حدث خطأ');
          }

          final students = state.students;

          // تهيئة الـ map بالقيمة الافتراضية (حاضر)
          for (final s in students) {
            _attendanceMap.putIfAbsent(s.uid, () => AttendanceStatus.present);
          }

          // حساب العدادات
          final presentCount = _attendanceMap.values
              .where((v) => v == AttendanceStatus.present)
              .length;
          final absentCount = _attendanceMap.values
              .where((v) => v == AttendanceStatus.absent)
              .length;
          final lateCount = _attendanceMap.values
              .where((v) => v == AttendanceStatus.late)
              .length;
          const excusedCount = 0; // placeholder

          return Column(
            children: [
              // ── التاريخ المحدد ─────────────────────────────────
              _DateNavigator(
                date: _selectedDate,
                onPrev: () => setState(
                  () => _selectedDate = _selectedDate.subtract(
                    const Duration(days: 1),
                  ),
                ),
                onNext: () => setState(
                  () => _selectedDate = _selectedDate.add(
                    const Duration(days: 1),
                  ),
                ),
              ),

              // ── عدادات الحضور ──────────────────────────────────
              _AttendanceSummaryRow(
                present: presentCount,
                absent: absentCount,
                late: lateCount,
                excused: excusedCount,
              ),

              // ── جدول الطلاب ───────────────────────────────────
              Expanded(
                child: ListView.separated(
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
                      status:
                          _attendanceMap[student.uid] ??
                          AttendanceStatus.present,
                      onChanged: (status) =>
                          setState(() => _attendanceMap[student.uid] = status),
                    );
                  },
                ),
              ),

              // ── زرار الحفظ ─────────────────────────────────────
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
                  onPressed: _saveAttendance,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveAttendance() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final bloc = context.read<TeacherBloc>();

    for (final entry in _attendanceMap.entries) {
      bloc.add(
        RecordAttendanceEvent(
          AttendanceRecordEntity(
            id: '',
            studentId: entry.key,
            studentName: bloc.state.students
                .firstWhere(
                  (s) => s.uid == entry.key,
                  orElse: () =>
                      const HalaqaStudentSummaryEntity(uid: '', name: ''),
                )
                .name,
            halaqaId: widget.halaqaId,
            date: _selectedDate,
            status: entry.value,
            recordedBy: authState.user.uid,
          ),
        ),
      );
    }

    AppSnackBar.showSuccess(context, 'تم حفظ الحضور بنجاح');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DateNavigator
// ══════════════════════════════════════════════════════════════════════════════

class _DateNavigator extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

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
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
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
            onPressed: onNext, // الأحدث على اليسار (RTL)
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

// ══════════════════════════════════════════════════════════════════════════════
// _AttendanceSummaryRow - العدادات الأربعة
// ══════════════════════════════════════════════════════════════════════════════

class _AttendanceSummaryRow extends StatelessWidget {
  final int present;
  final int absent;
  final int late;
  final int excused;

  const _AttendanceSummaryRow({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
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
            value: excused,
            label: 'معذور',
            color: AppColors.primaryLight,
            textColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
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

// ══════════════════════════════════════════════════════════════════════════════
// _StudentAttendanceRow - صف طالب واحد مع أزرار الحضور/الغياب/التأخر
// ══════════════════════════════════════════════════════════════════════════════

class _StudentAttendanceRow extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;
  final AttendanceStatus status;
  final void Function(AttendanceStatus) onChanged;

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
          // أزرار الحضور
          Row(
            children: [
              _AttendanceButton(
                label: '!',
                isActive: status == AttendanceStatus.late,
                activeColor: AppColors.secondary,
                onTap: () => onChanged(AttendanceStatus.late),
              ),
              const SizedBox(width: 6),
              _AttendanceButton(
                label: '✗',
                isActive: status == AttendanceStatus.absent,
                activeColor: AppColors.error,
                onTap: () => onChanged(AttendanceStatus.absent),
              ),
              const SizedBox(width: 6),
              _AttendanceButton(
                label: '✓',
                isActive: status == AttendanceStatus.present,
                activeColor: AppColors.success,
                onTap: () => onChanged(AttendanceStatus.present),
              ),
            ],
          ),

          const Spacer(),

          // اسم الطالب
          Text(student.name, style: AppTextStyles.titleMedium),
          const SizedBox(width: 12),

          // Avatar
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
  final VoidCallback onTap;

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
