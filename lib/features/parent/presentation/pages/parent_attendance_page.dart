import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/parent_household.dart';
import '../../domain/usecases/get_attendance_marks_usecase.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentAttendancePage extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ParentAttendancePage({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<ParentAttendancePage> createState() => _ParentAttendancePageState();
}

class _ParentAttendancePageState extends State<ParentAttendancePage> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<ParentAttendanceMark> _marks = const [];

  static const _weekdays = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1);
    final result = await sl<GetAttendanceMarksUseCase>()(
      AttendanceMarksParams(
        parentId: auth.user.uid,
        studentId: widget.studentId,
        start: start,
        endExclusive: end,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (marks) => setState(() {
        _loading = false;
        _marks = marks;
      }),
    );
  }

  Map<DateTime, String> get _byDay {
    final map = <DateTime, String>{};
    for (final mark in _marks) {
      final day = AttendancePolicy.dayStart(mark.date);
      map[day] = mark.status;
    }
    return map;
  }

  int _count(String status) => _byDay.values.where((s) => s == status).length;

  double? get _percent {
    final present = _count(AttendancePolicy.statusPresent);
    final late = _count(AttendancePolicy.statusLate);
    final absent = _count(AttendancePolicy.statusAbsent);
    final denom = present + late + absent;
    if (denom == 0) return null;
    return ((present + late) / denom) * 100;
  }

  Color? _colorFor(String? status) {
    return switch ((status ?? '').trim()) {
      AttendancePolicy.statusPresent => AppColors.success,
      AttendancePolicy.statusAbsent => AppColors.error,
      AttendancePolicy.statusLate => AppColors.secondary,
      AttendancePolicy.statusExcused => AppColors.info,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.studentName ?? '').trim();
    final byDay = _byDay;
    HijriCalendar.setLocal('ar');
    final hijri = HijriCalendar.fromDate(_month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final leading = firstWeekday % 7; // Saturday-first grid

    return ParentSubpageScaffold(
      title: name.isEmpty ? 'سجل الحضور' : 'سجل الحضور — $name',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              _StatChip(
                label: 'حاضر',
                color: const Color(0xFFE8F5E9),
                value: _count(AttendancePolicy.statusPresent),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'غائب',
                color: const Color(0xFFFFEBEE),
                value: _count(AttendancePolicy.statusAbsent),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'متأخر',
                color: AppColors.secondaryBg,
                value: _count(AttendancePolicy.statusLate),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'معذور',
                color: AppColors.primaryLight,
                value: _count(AttendancePolicy.statusExcused),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'نسبة الحضور الشهرية',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      parentPercentLabel(_percent),
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  child: LinearProgressIndicator(
                    value: ((_percent ?? 0) / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                          });
                          _load();
                        },
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          hijri.toFormat('MMMM yyyy'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                          });
                          _load();
                        },
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final day in _weekdays)
                            Expanded(
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const ParentCalendarSkeleton()
                      else if (_error != null)
                        AppErrorWidget(message: _error!, onRetry: _load)
                      else if (_marks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 28,
                          ),
                          child: Text(
                            'لا يوجد حضور مسجّل لهذا الشهر بعد.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: leading + daysInMonth,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                          itemBuilder: (context, index) {
                            if (index < leading) {
                              return const SizedBox.shrink();
                            }
                            final day = index - leading + 1;
                            final date = DateTime(
                              _month.year,
                              _month.month,
                              day,
                            );
                            final status =
                                byDay[AttendancePolicy.dayStart(date)];
                            final color = _colorFor(status);
                            final isToday = AttendancePolicy.isSameCalendarDay(
                              date,
                              DateTime.now(),
                            );
                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    color?.withValues(alpha: 0.16) ??
                                    Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday
                                    ? Border.all(
                                        color: AppColors.primary,
                                        width: 1.4,
                                      )
                                    : null,
                              ),
                              child: Text(
                                parentEasternDigits('$day'),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: color ?? AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: AppColors.success, label: 'حاضر'),
                          SizedBox(width: 10),
                          _LegendDot(color: AppColors.error, label: 'غائب'),
                          SizedBox(width: 10),
                          _LegendDot(
                            color: AppColors.secondary,
                            label: 'متأخر',
                          ),
                          SizedBox(width: 10),
                          _LegendDot(color: AppColors.info, label: 'معذور'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final int value;

  const _StatChip({
    required this.label,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              parentEasternDigits('$value'),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}
