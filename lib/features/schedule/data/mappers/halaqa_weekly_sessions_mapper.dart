import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/entities/class_session_entity.dart';
import '../models/class_session_model.dart';
import '../models/halaqa_schedule_source_model.dart';

/// Maps raw `halaqat.schedule` slots into weekly [ClassSessionEntity] rows.
///
/// Also derives **today's operational days** for W3 orchestration (D6/D7):
/// one row per halaqa that has a schedule slot today, stably ordered.
/// Does **not** encode attendance/homework/review rules — those stay in W1/W2.
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

  /// Today's operational teaching days across [sources] (W3 Pre-Slice).
  ///
  /// - Filters to the calendar day of [now] via [AttendancePolicy.dayStart].
  /// - Collapses multiple same-day slots for one halaqa into **one** row (D6).
  /// - Orders by earliest start time, then `halaqaId` (D7 — never random).
  /// - Pure derivation; no persistence (D8/D10).
  List<ClassSessionEntity> mapTodayOperationalDays(
    Iterable<HalaqaScheduleSourceModel> sources, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = AttendancePolicy.dayStart(clock);
    final byHalaqa = <String, ClassSessionEntity>{};

    for (final source in sources) {
      final halaqaId = source.halaqaId.trim();
      if (halaqaId.isEmpty) continue;

      for (final session in map(source, now: clock)) {
        final sessionDay = AttendancePolicy.dayStart(session.startAt);
        if (sessionDay != today) continue;

        final existing = byHalaqa[halaqaId];
        if (existing == null) {
          byHalaqa[halaqaId] = _asOperationalDay(
            halaqaId: halaqaId,
            day: today,
            session: session,
            clock: clock,
          );
          continue;
        }

        // D6: one operational day — earliest start, latest end.
        final startAt = session.startAt.isBefore(existing.startAt)
            ? session.startAt
            : existing.startAt;
        final endAt = session.endAt.isAfter(existing.endAt)
            ? session.endAt
            : existing.endAt;
        byHalaqa[halaqaId] = ClassSessionModel(
          id: existing.id,
          title: existing.title,
          type: existing.type,
          startAt: startAt,
          endAt: endAt,
          teacherName: existing.teacherName,
          status: _statusFor(clock, startAt, endAt),
          meetingLink: existing.meetingLink.isNotEmpty
              ? existing.meetingLink
              : session.meetingLink,
          topic: existing.topic,
        );
      }
    }

    final days = byHalaqa.entries.toList()
      ..sort((a, b) {
        final byTime = a.value.startAt.compareTo(b.value.startAt);
        if (byTime != 0) return byTime;
        // D7 stable fallback: Firestore halaqa document id (map key).
        return a.key.compareTo(b.key);
      });
    return days.map((e) => e.value).toList();
  }

  ClassSessionEntity _asOperationalDay({
    required String halaqaId,
    required DateTime day,
    required ClassSessionEntity session,
    required DateTime clock,
  }) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return ClassSessionModel(
      id: '${halaqaId}_$y$m$d',
      title: session.title,
      type: session.type,
      startAt: session.startAt,
      endAt: session.endAt,
      teacherName: session.teacherName,
      status: _statusFor(clock, session.startAt, session.endAt),
      meetingLink: session.meetingLink,
      topic: session.topic,
    );
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
    final today = AttendancePolicy.dayStart(now);
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
