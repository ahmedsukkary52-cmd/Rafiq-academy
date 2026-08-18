import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  int _count(String status) =>
      _byDay.values.where((s) => s == status).length;

  @override
  Widget build(BuildContext context) {
    final name = (widget.studentName ?? '').trim();
    final byDay = _byDay;
    return ParentSubpageScaffold(
      title: name.isEmpty ? 'سجل الحضور' : 'سجل الحضور — $name',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _StatChip(
                  label: 'حاضر',
                  color: AppColors.successBg,
                  value: '${_count(AttendancePolicy.statusPresent)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'غائب',
                  color: const Color(0xFFFFEBEE),
                  value: '${_count(AttendancePolicy.statusAbsent)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'متأخر',
                  color: AppColors.secondaryBg,
                  value: '${_count(AttendancePolicy.statusLate)}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'معذور',
                  color: AppColors.primaryLight,
                  value: '${_count(AttendancePolicy.statusExcused)}',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_month.year}/${_month.month.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const ParentListCardsSkeleton()
                : _error != null
                ? AppErrorWidget(message: _error!, onRetry: _load)
                : byDay.isEmpty
                ? const ParentEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'لا توجد سجلات حضور في هذا الشهر',
                    message:
                        'يُعرض هنا الحاضر والغائب والمتأخر والمعذور من سجلات الحضور الموجودة.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: byDay.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final days = byDay.keys.toList()
                        ..sort((a, b) => b.compareTo(a));
                      final day = days[index];
                      final status = byDay[day];
                      return AppCard(
                        child: Row(
                          children: [
                            Text(
                              parentAttendanceLabel(status),
                              style: AppTextStyles.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${day.day}/${day.month}/${day.year}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
  final String value;

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
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Text(
          '$value\n$label',
          style: AppTextStyles.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
