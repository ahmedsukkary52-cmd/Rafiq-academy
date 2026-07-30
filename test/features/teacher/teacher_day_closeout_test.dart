import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/domain/read_models/teacher_day_agenda.dart';

/// W3 Slice 4 — Day Closeout is a **pure projection** of TeacherDayAgenda.
///
/// These tests pin the derivation matrix (no I/O, no new business rules):
///   sessionsTodayCount == 0        → noSession
///   sessionsTodayCount > 0 & empty → complete
///   items.isNotEmpty               → incomplete
/// and the count arithmetic (completed = total - remaining, clamped).
void main() {
  TeacherAgendaItem item(String id) => TeacherAgendaItem(
    halaqaId: id,
    halaqaName: 'حلقة $id',
    startAt: DateTime(2024, 6, 3, 9),
    pendingActions: const [TeacherAgendaAction.takeAttendance],
  );

  group('TeacherDayAgenda.closeout', () {
    test('no halaqat meet today → noSession', () {
      const agenda = TeacherDayAgenda(items: [], sessionsTodayCount: 0);
      final c = agenda.closeout;

      expect(c.status, DayCloseoutStatus.noSession);
      expect(c.totalHalaqat, 0);
      expect(c.completedHalaqat, 0);
      expect(c.remainingHalaqat, 0);
    });

    test('sessions today with no remaining work → complete', () {
      const agenda = TeacherDayAgenda(items: [], sessionsTodayCount: 3);
      final c = agenda.closeout;

      expect(c.status, DayCloseoutStatus.complete);
      expect(c.totalHalaqat, 3);
      expect(c.completedHalaqat, 3);
      expect(c.remainingHalaqat, 0);
    });

    test('some remaining work → incomplete with correct fraction', () {
      final agenda = TeacherDayAgenda(
        items: [item('a')],
        sessionsTodayCount: 3,
      );
      final c = agenda.closeout;

      expect(c.status, DayCloseoutStatus.incomplete);
      expect(c.totalHalaqat, 3);
      expect(c.completedHalaqat, 2);
      expect(c.remainingHalaqat, 1);
    });

    test('all today halaqat remaining → incomplete, zero completed', () {
      final agenda = TeacherDayAgenda(
        items: [item('a'), item('b')],
        sessionsTodayCount: 2,
      );
      final c = agenda.closeout;

      expect(c.status, DayCloseoutStatus.incomplete);
      expect(c.completedHalaqat, 0);
      expect(c.remainingHalaqat, 2);
    });

    test('single-halaqa incomplete day', () {
      final agenda = TeacherDayAgenda(
        items: [item('a')],
        sessionsTodayCount: 1,
      );
      final c = agenda.closeout;

      expect(c.status, DayCloseoutStatus.incomplete);
      expect(c.completedHalaqat, 0);
    });

    test('completed count never goes negative (clamped)', () {
      // Defensive: items can never exceed today's halaqat, but the projection
      // must still be total-safe.
      final agenda = TeacherDayAgenda(
        items: [item('a'), item('b'), item('c')],
        sessionsTodayCount: 2,
      );
      final c = agenda.closeout;

      expect(c.completedHalaqat, 0);
      expect(c.status, DayCloseoutStatus.incomplete);
    });

    test('closeout adds no new state — derived only from agenda fields', () {
      // Same inputs → equal closeout (value equality via Equatable).
      const a = TeacherDayAgenda(items: [], sessionsTodayCount: 2);
      const b = TeacherDayAgenda(items: [], sessionsTodayCount: 2);
      expect(a.closeout, b.closeout);
    });
  });
}
