import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/schedule/data/mappers/halaqa_weekly_sessions_mapper.dart';
import 'package:rafiq_academy/features/schedule/data/models/halaqa_schedule_source_model.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/class_session_entity.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  const mapper = HalaqaWeeklySessionsMapper();

  /// Fixed Wednesday so day labels stay stable across CI locales/clocks.
  final now = DateTime(2026, 7, 22, 10, 0); // Wednesday
  const todayLabel = 'الأربعاء';
  const otherDayLabel = 'السبت';
  const thursdayLabel = 'الخميس';

  HalaqaScheduleSourceModel source({
    required String id,
    required String name,
    List<HalaqaScheduleSlotModel> schedule = const [],
    String meetingLink = '',
  }) {
    return HalaqaScheduleSourceModel(
      halaqaId: id,
      name: name,
      meetingLink: meetingLink,
      schedule: schedule,
    );
  }

  HalaqaScheduleSlotModel slot({
    required String day,
    required String start,
    required String end,
  }) {
    return HalaqaScheduleSlotModel(day: day, startTime: start, endTime: end);
  }

  group('mapTodayOperationalDays (W3 Pre-Slice)', () {
    test('empty sources → empty agenda', () {
      expect(mapper.mapTodayOperationalDays(const [], now: now), isEmpty);
    });

    test('empty schedule on a halaqa → empty agenda', () {
      final days = mapper.mapTodayOperationalDays([
        source(id: 'h1', name: 'حلقة أ', schedule: const []),
      ], now: now);

      expect(days, isEmpty);
    });

    test('no sessions today → empty agenda', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [slot(day: otherDayLabel, start: '16:00', end: '17:00')],
        ),
      ], now: now);

      expect(days, isEmpty);
    });

    test('one session today → one operational day', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          meetingLink: 'https://meet.example/a',
          schedule: [slot(day: todayLabel, start: '16:00', end: '17:00')],
        ),
      ], now: now);

      expect(days, hasLength(1));
      expect(days.single.id, 'h1_20260722');
      expect(days.single.title, 'حلقة أ');
      expect(days.single.startAt, DateTime(2026, 7, 22, 16, 0));
      expect(days.single.endAt, DateTime(2026, 7, 22, 17, 0));
      expect(days.single.meetingLink, 'https://meet.example/a');
      expect(days.single.status, ClassSessionStatus.upcoming);
    });

    test('multiple halaqat today ordered by start time', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h_late',
          name: 'متأخرة',
          schedule: [slot(day: todayLabel, start: '18:00', end: '19:00')],
        ),
        source(
          id: 'h_early',
          name: 'مبكرة',
          schedule: [slot(day: todayLabel, start: '08:00', end: '09:00')],
        ),
      ], now: now);

      expect(days.map((d) => d.title).toList(), ['مبكرة', 'متأخرة']);
    });

    test('multiple slots same halaqa collapse to one day (D6)', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [
            slot(day: todayLabel, start: '16:00', end: '17:00'),
            slot(day: todayLabel, start: '09:00', end: '10:00'),
          ],
        ),
      ], now: now);

      expect(days, hasLength(1));
      expect(days.single.startAt, DateTime(2026, 7, 22, 9, 0));
      expect(days.single.endAt, DateTime(2026, 7, 22, 17, 0));
      expect(days.single.status, ClassSessionStatus.live);
    });

    test('slots listed out of chronological order still order correctly', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h_z',
          name: 'لاحقاً',
          schedule: [slot(day: todayLabel, start: '20:00', end: '21:00')],
        ),
        source(
          id: 'h_m',
          name: 'منتصف',
          schedule: [slot(day: todayLabel, start: '14:00', end: '15:00')],
        ),
        source(
          id: 'h_a',
          name: 'أولاً',
          schedule: [slot(day: todayLabel, start: '07:00', end: '08:00')],
        ),
      ], now: now);

      expect(days.map((d) => d.title).toList(), ['أولاً', 'منتصف', 'لاحقاً']);
    });

    test('same start time → stable halaqaId order (D7)', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h_b',
          name: 'باء',
          schedule: [slot(day: todayLabel, start: '10:00', end: '11:00')],
        ),
        source(
          id: 'h_a',
          name: 'ألف',
          schedule: [slot(day: todayLabel, start: '10:00', end: '11:00')],
        ),
      ], now: now);

      expect(days.map((d) => d.id).toList(), ['h_a_20260722', 'h_b_20260722']);
    });

    test('duplicate identical schedule entries collapse to one day', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [
            slot(day: todayLabel, start: '16:00', end: '17:00'),
            slot(day: todayLabel, start: '16:00', end: '17:00'),
          ],
        ),
      ], now: now);

      expect(days, hasLength(1));
      expect(days.single.startAt, DateTime(2026, 7, 22, 16, 0));
      expect(days.single.endAt, DateTime(2026, 7, 22, 17, 0));
    });

    test('day boundary: late Wednesday still includes Wednesday slots', () {
      final late = DateTime(2026, 7, 22, 23, 59);
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [slot(day: todayLabel, start: '08:00', end: '09:00')],
        ),
      ], now: late);

      expect(days, hasLength(1));
      expect(
        AttendancePolicy.dayStart(days.single.startAt),
        AttendancePolicy.dayStart(late),
      );
      expect(days.single.status, ClassSessionStatus.ended);
    });

    test('day boundary: just after midnight excludes previous weekday', () {
      final thursday = DateTime(2026, 7, 23, 0, 1);
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [
            slot(day: todayLabel, start: '16:00', end: '17:00'),
            slot(day: thursdayLabel, start: '09:00', end: '10:00'),
          ],
        ),
      ], now: thursday);

      expect(days, hasLength(1));
      expect(days.single.startAt, DateTime(2026, 7, 23, 9, 0));
      expect(days.single.id, 'h1_20260723');
    });

    test(
      'overnight-looking end before start keeps pre-existing map() clamp',
      () {
        // Pre-existing map() rule: endAt <= startAt → startAt + 1h (same day).
        final days = mapper.mapTodayOperationalDays([
          source(
            id: 'h1',
            name: 'حلقة أ',
            schedule: [slot(day: todayLabel, start: '22:00', end: '01:00')],
          ),
        ], now: now);

        expect(days, hasLength(1));
        expect(days.single.startAt, DateTime(2026, 7, 22, 22, 0));
        expect(days.single.endAt, DateTime(2026, 7, 22, 23, 0));
      },
    );

    test('deterministic: same inputs → identical output twice', () {
      final sources = [
        source(
          id: 'h_b',
          name: 'باء',
          schedule: [slot(day: todayLabel, start: '10:00', end: '11:00')],
        ),
        source(
          id: 'h_a',
          name: 'ألف',
          schedule: [slot(day: todayLabel, start: '09:00', end: '10:00')],
        ),
      ];

      final a = mapper.mapTodayOperationalDays(sources, now: now);
      final b = mapper.mapTodayOperationalDays(sources, now: now);

      expect(a, b);
      expect(a.map((e) => e.id).toList(), b.map((e) => e.id).toList());
    });

    test('skips empty halaqaId and unparseable start times', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: '',
          name: 'بدون معرف',
          schedule: [slot(day: todayLabel, start: '10:00', end: '11:00')],
        ),
        source(
          id: 'h1',
          name: 'وقت غير صالح',
          schedule: [slot(day: todayLabel, start: 'soon', end: '11:00')],
        ),
        source(
          id: 'h2',
          name: 'صالحة',
          schedule: [slot(day: todayLabel, start: '12:00', end: '13:00')],
        ),
      ], now: now);

      expect(days, hasLength(1));
      expect(days.single.id, 'h2_20260722');
    });
  });

  group('map() regression (existing student schedule consumer)', () {
    test('weekly list still returns all week slots', () {
      final weekly = mapper.map(
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [
            slot(day: todayLabel, start: '16:00', end: '17:00'),
            slot(day: otherDayLabel, start: '16:00', end: '17:00'),
          ],
        ),
        now: now,
      );

      expect(weekly, hasLength(2));
      expect(weekly.first.startAt.isBefore(weekly.last.startAt), isTrue);
    });

    test('map() sorts by startAt regardless of slot input order', () {
      final weekly = mapper.map(
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [
            slot(day: otherDayLabel, start: '18:00', end: '19:00'),
            slot(day: todayLabel, start: '08:00', end: '09:00'),
          ],
        ),
        now: now,
      );

      expect(weekly, hasLength(2));
      expect(weekly[0].startAt, DateTime(2026, 7, 22, 8, 0));
      expect(weekly[1].startAt, DateTime(2026, 7, 25, 18, 0));
    });
  });
}
