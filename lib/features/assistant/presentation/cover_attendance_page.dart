import 'package:flutter/material.dart';

import '../../../core/error/exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/attendance_policy.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../data/cover_duty_repository.dart';

/// Today's attendance for a covered halaqa. The server checks the active
/// cover, the session day and the roster, keeps the primary teacher on the
/// session and stamps the cover as the person who handled it.
class CoverAttendancePage extends StatefulWidget {
  final DutyHalaqa halaqa;
  final CoverDutyRepository repository;
  final DateTime Function() now;

  const CoverAttendancePage({
    super.key,
    required this.halaqa,
    required this.repository,
    this.now = DateTime.now,
  });

  @override
  State<CoverAttendancePage> createState() => _CoverAttendancePageState();
}

class _CoverAttendancePageState extends State<CoverAttendancePage> {
  static const _statuses = {
    AttendancePolicy.statusPresent: 'حاضر',
    AttendancePolicy.statusLate: 'متأخر',
    AttendancePolicy.statusAbsent: 'غائب',
    AttendancePolicy.statusExcused: 'معذور',
  };

  List<DutyStudent>? _students;
  final Map<String, String> _marks = {};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repository.roster(widget.halaqa);
      if (!mounted) return;
      setState(() {
        _students = list;
        for (final s in list) {
          _marks.putIfAbsent(s.uid, () => AttendancePolicy.statusPresent);
        }
      });
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.recordAttendance(
        halaqaId: widget.halaqa.id,
        day: widget.now(),
        marks: Map.of(_marks),
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'تم حفظ الحضور');
      Navigator.of(context).maybePop();
    } on ServerException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('حضور ${widget.halaqa.displayName}')),
        body: _error != null
            ? Center(child: Text(_error!))
            : students == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                children: [
                  Text(
                    'تسجّل بصفتك تغطية مؤقتة؛ يبقى ${widget.halaqa.teacherName.isEmpty ? 'المعلم الأساسي' : widget.halaqa.teacherName} معلم الحلقة.',
                    style: AppTextStyles.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  if (students.isEmpty) const Text('لا يوجد طلاب في الحلقة.'),
                  for (final s in students)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(s.name.isEmpty ? 'طالب' : s.name, style: AppTextStyles.bodyMedium),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final e in _statuses.entries)
                                ChoiceChip(
                                  key: Key('mark-${s.name}-${e.key}'),
                                  label: Text(e.value),
                                  selected: _marks[s.uid] == e.key,
                                  onSelected: (_) => setState(() => _marks[s.uid] = e.key),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppButton(
                    key: const Key('cover-attendance-save'),
                    label: 'حفظ الحضور',
                    isLoading: _saving,
                    onPressed: students.isEmpty || _saving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}
