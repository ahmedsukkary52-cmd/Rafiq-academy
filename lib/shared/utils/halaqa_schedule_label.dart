import '../../features/student/domain/entities/halaqa_entity.dart';

/// Builds a display label for a halaqa weekly schedule.
///
/// When multiple slots use different times, only the days are shown so a single
/// time is never applied to every day incorrectly.
String? halaqaScheduleLabel(
  List<HalaqaScheduleEntity> schedule, {
  bool compactDays = false,
}) {
  if (schedule.isEmpty) return null;

  final days = schedule
      .map((s) => compactDays ? _dayShort(s.day) : s.day.trim())
      .where((d) => d.isNotEmpty)
      .toList();
  final daysLabel = days.join('، ');

  final timeKeys = <String>{};
  for (final slot in schedule) {
    final start = slot.startTime.trim();
    final end = slot.endTime.trim();
    if (start.isEmpty && end.isEmpty) continue;
    timeKeys.add(end.isEmpty ? start : '$start–$end');
  }

  if (daysLabel.isEmpty && timeKeys.isEmpty) return null;
  if (timeKeys.isEmpty) return daysLabel.isEmpty ? null : daysLabel;
  if (timeKeys.length == 1) {
    final timeLabel = timeKeys.first;
    if (daysLabel.isEmpty) return timeLabel;
    return '$daysLabel · $timeLabel';
  }
  return daysLabel.isEmpty ? null : daysLabel;
}

String _dayShort(String day) => switch (day.trim()) {
  'الأحد' => 'أح',
  'الاثنين' => 'إث',
  'الثلاثاء' => 'ثل',
  'الأربعاء' => 'أر',
  'الخميس' => 'خم',
  'الجمعة' => 'جم',
  'السبت' => 'سب',
  _ => day.trim(),
};
