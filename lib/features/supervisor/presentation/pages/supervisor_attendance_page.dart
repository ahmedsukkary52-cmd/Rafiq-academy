import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../teacher/domain/entities/attendance_record_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_attendance_for_date_usecase.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

class SupervisorAttendancePage extends StatefulWidget {
  final String? initialHalaqaId;

  const SupervisorAttendancePage({super.key, this.initialHalaqaId});

  @override
  State<SupervisorAttendancePage> createState() =>
      _SupervisorAttendancePageState();
}

class _SupervisorAttendancePageState extends State<SupervisorAttendancePage> {
  late DateTime _date;
  String? _halaqaId;
  bool _loading = false;
  String? _error;
  List<AttendanceRecordEntity> _records = const [];
  List<HalaqaStudentSummaryEntity> _students = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _halaqaId = widget.initialHalaqaId?.trim();
    if (_halaqaId != null && _halaqaId!.isEmpty) _halaqaId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final halaqat = context.read<SupervisorBloc>().state.halaqat;
      if (_halaqaId == null && halaqat.isNotEmpty) {
        setState(() => _halaqaId = halaqat.first.id);
      }
      _load();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _load() async {
    final halaqaId = _halaqaId;
    if (halaqaId == null || halaqaId.isEmpty) {
      setState(() {
        _records = const [];
        _students = const [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final attendanceResult = await sl<GetHalaqaAttendanceForDateUseCase>()(
      HalaqaAttendanceDateParams(halaqaId: halaqaId, date: _date),
    );
    final studentsResult = await sl<GetHalaqaStudentsUseCase>()(
      HalaqaStudentsParams(halaqaId),
    );
    if (!mounted) return;

    String? error;
    var records = <AttendanceRecordEntity>[];
    var students = <HalaqaStudentSummaryEntity>[];

    attendanceResult.fold((f) => error = f.message, (r) => records = r);
    studentsResult.fold((f) => error ??= f.message, (s) => students = s);

    setState(() {
      _loading = false;
      _error = error;
      _records = records;
      _students = students;
    });
  }

  int _count(AttendanceStatus status) =>
      _records.where((r) => r.status == status).length;

  String _statusLabel(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => 'حاضر',
    AttendanceStatus.absent => 'غائب',
    AttendanceStatus.late => 'متأخر',
    AttendanceStatus.excused => 'معذور',
  };

  Color _statusColor(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.absent => AppColors.error,
    AttendanceStatus.late => AppColors.secondary,
    AttendanceStatus.excused => AppColors.info,
  };

  String _nameFor(String studentId) {
    for (final s in _students) {
      if (s.uid == studentId) {
        final n = s.name.trim();
        return n.isEmpty ? studentId : n;
      }
    }
    for (final r in _records) {
      if (r.studentId == studentId) {
        final n = r.studentName.trim();
        return n.isEmpty ? studentId : n;
      }
    }
    return studentId;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}';

    return SupervisorSubpageScaffold(
      title: 'الحضور',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) => p.halaqat != c.halaqat,
        builder: (context, state) {
          final halaqat = state.halaqat;
          if (_halaqaId != null &&
              !halaqat.any((h) => h.id == _halaqaId) &&
              halaqat.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _halaqaId = halaqat.first.id);
              _load();
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(dateLabel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value:
                          _halaqaId != null &&
                              halaqat.any((h) => h.id == _halaqaId)
                          ? _halaqaId
                          : null,
                      decoration: const InputDecoration(labelText: 'الحلقة'),
                      items: [
                        for (final h in halaqat)
                          DropdownMenuItem(
                            value: h.id,
                            child: Text(
                              h.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: halaqat.isEmpty
                          ? null
                          : (v) {
                              setState(() => _halaqaId = v);
                              _load();
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: AppErrorWidget(message: _error!, onRetry: _load),
                )
              else if (_halaqaId == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'اختر حلقة لعرض الحضور',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Row(
                        children: [
                          _StatChip(
                            label: 'حاضر',
                            value: _count(AttendanceStatus.present),
                            color: const Color(0xFFE8F5E9),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'متأخر',
                            value: _count(AttendanceStatus.late),
                            color: AppColors.secondaryBg,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'غائب',
                            value: _count(AttendanceStatus.absent),
                            color: const Color(0xFFFFEBEE),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'معذور',
                            value: _count(AttendanceStatus.excused),
                            color: AppColors.primaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لا توجد سجلات حضور لهذا اليوم',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        )
                      else
                        ..._records.map((r) {
                          final color = _statusColor(r.status);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_nameFor(r.studentId)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                _statusLabel(r.status),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}
