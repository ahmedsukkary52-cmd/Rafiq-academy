import '../../domain/entities/class_session_entity.dart';
import '../models/class_session_model.dart';
import '../models/halaqa_schedule_source_model.dart';

/// Maps raw `halaqat.schedule` slots into weekly [ClassSessionEntity] rows.
class HalaqaWeeklySessionsMapper {
  const HalaqaWeeklySessionsMapper();

  List<ClassSessionEntity> map(
    HalaqaScheduleSourceModel source, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final title = source.name.isNotEmpty ? source.name : 'حصة الحلقة';
    final sessions = <ClassSessionEntity>[];

    for (var i = 0; i < source.schedule.length; i++) {
      final slot = source.schedule[i];
      final weekday = _weekdayFromLabel(slot.day);
      if (weekday == null) continue;

      final startClock = _parseClock(slot.startTime);
      final endClock = _parseClock(slot.endTime);
      if (startClock == null) continue;

      final day = _dateForWeekdayInCurrentWeek(weekday, clock);
      final startAt = DateTime(
        day.year,
        day.month,
        day.day,
        startClock.$1,
        startClock.$2,
      );
      var endAt = endClock == null
          ? startAt.add(const Duration(hours: 1))
          : DateTime(day.year, day.month, day.day, endClock.$1, endClock.$2);
      if (!endAt.isAfter(startAt)) {
        endAt = startAt.add(const Duration(hours: 1));
      }

      sessions.add(
        ClassSessionModel(
          id: '${source.halaqaId}_$i',
          title: title,
          type: ClassSessionType.other,
          startAt: startAt,
          endAt: endAt,
          teacherName: '',
          status: _statusFor(clock, startAt, endAt),
          meetingLink: source.meetingLink,
        ),
      );
    }

    sessions.sort((a, b) => a.startAt.compareTo(b.startAt));
    return sessions;
  }

  ClassSessionStatus _statusFor(
    DateTime now,
    DateTime startAt,
    DateTime endAt,
  ) {
    if (now.isBefore(startAt)) return ClassSessionStatus.upcoming;
    if (now.isAfter(endAt) || now.isAtSameMomentAs(endAt)) {
      return ClassSessionStatus.ended;
    }
    return ClassSessionStatus.live;
  }

  /// Returns DateTime.weekday (1=Mon … 7=Sun) for Arabic/English day labels.
  int? _weekdayFromLabel(String raw) {
    final day = raw.trim().toLowerCase();
    if (day.isEmpty) return null;

    const map = <String, int>{
      // Arabic (teacher / supervisor convention)
      'الاثنين': DateTime.monday,
      'الإثنين': DateTime.monday,
      'الثلاثاء': DateTime.tuesday,
      'الأربعاء': DateTime.wednesday,
      'الاربعاء': DateTime.wednesday,
      'الخميس': DateTime.thursday,
      'الجمعة': DateTime.friday,
      'السبت': DateTime.saturday,
      'الأحد': DateTime.sunday,
      'الاحد': DateTime.sunday,
      // English
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };

    return map[day] ?? map[raw.trim()];
  }

  DateTime _dateForWeekdayInCurrentWeek(int weekday, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: weekday - today.weekday));
  }

  /// Parses `HH:mm`, `H:mm`, `h:mm AM/PM`, and Arabic ص/م variants.
  (int, int)? _parseClock(String raw) {
    final text = _normalizeDigits(raw.trim());
    if (text.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})[:\.](\d{2})\s*(ص|م|am|pm)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final period = match.group(3)?.toLowerCase();
    if (period != null) {
      final isPm = period == 'م' || period == 'pm';
      final isAm = period == 'ص' || period == 'am';
      if (isPm || isAm) {
        hour = hour % 12;
        if (isPm) hour += 12;
      }
    }

    return (hour, minute);
  }

  String _normalizeDigits(String input) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      final ch = String.fromCharCode(unit);
      final e = eastern.indexOf(ch);
      if (e >= 0) {
        buffer.write(e);
        continue;
      }
      final p = persian.indexOf(ch);
      if (p >= 0) {
        buffer.write(p);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }
}
