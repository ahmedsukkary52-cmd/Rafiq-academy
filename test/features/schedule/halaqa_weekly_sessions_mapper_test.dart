import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/schedule/data/mappers/halaqa_weekly_sessions_mapper.dart';
import 'package:rafiq_academy/features/schedule/data/models/halaqa_schedule_source_model.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/class_session_entity.dart';

void main() {
  const mapper = HalaqaWeeklySessionsMapper();

  /// Fixed Wednesday so day labels stay stable across CI locales/clocks.
  final now = DateTime(2026, 7, 22, 10, 0); // Wednesday
  const todayLabel = 'الأربعاء';
  const otherDayLabel = 'السبت';

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

    test('no slot on today → empty agenda', () {
      final days = mapper.mapTodayOperationalDays([
        source(
          id: 'h1',
          name: 'حلقة أ',
          schedule: [slot(day: otherDayLabel, start: '16:00', end: '17:00')],
        ),
      ], now: now);

      expect(days, isEmpty);
    });

    test('one halaqa with today slot → one operational day', () {
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

    test('D6: multiple today slots for same halaqa collapse to one day', () {
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

    test('D7: multiple halaqat ordered by start time', () {
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

    test('D7: equal start times fall back to stable halaqaId order', () {
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

    test('map() weekly list still returns all week slots (regression)', () {
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
    });
  });
}
