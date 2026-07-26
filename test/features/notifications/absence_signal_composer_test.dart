import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/notifications/domain/services/absence_signal_composer.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  StudentAbsentRecorded absent({
    String studentId = 's1',
    String studentName = 'أحمد',
  }) => StudentAbsentRecorded(
    studentId: studentId,
    studentName: studentName,
    halaqaId: 'h1',
    date: date,
    attendanceDocumentId: 'h1_${studentId}_20240603',
  );

  StudentAbsenceCorrected corrected({String status = 'present'}) =>
      StudentAbsenceCorrected(
        studentId: 's1',
        studentName: 'أحمد',
        halaqaId: 'h1',
        date: date,
        attendanceDocumentId: 'h1_s1_20240603',
        correctedToStatus: status,
      );

  group('AbsenceSignalComposer', () {
    test('absence signal carries neutral copy and attendance type', () {
      final signals = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      );

      expect(signals, hasLength(1));
      final signal = signals.single;
      expect(signal.audience, 'p1');
      expect(signal.title, 'تم تسجيل غياب');
      expect(signal.body, 'تم تسجيل غياب أحمد بتاريخ 03/06/2024');
      expect(signal.type, NotificationTypes.attendance);
    });

    test('signal id is deterministic per parent and event', () {
      final first = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;
      final again = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;

      expect(first.id, again.id);
      expect(first.id, 'p1_attendance_absence_h1_s1_20240603');
    });

    test('correction replaces the same message it corrects', () {
      final absence = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;
      final correction = AbsenceSignalComposer.compose(
        events: [corrected()],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;

      expect(correction.id, absence.id);
      expect(correction.title, 'تم تحديث الحضور');
      expect(correction.body, 'تم تحديث حالة أحمد بتاريخ 03/06/2024 إلى حاضر');
    });

    test('correction to late is worded as late', () {
      final signal = AbsenceSignalComposer.compose(
        events: [corrected(status: 'late')],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;

      expect(signal.body, 'تم تحديث حالة أحمد بتاريخ 03/06/2024 إلى متأخر');
    });

    test('every linked parent gets an individually addressed signal', () {
      final signals = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {
          's1': ['p1', 'p2'],
        },
      );

      expect(signals.map((s) => s.audience), ['p1', 'p2']);
      expect(signals.map((s) => s.id).toSet(), hasLength(2));
    });

    test('student with no linked parent produces no signal', () {
      final signals = AbsenceSignalComposer.compose(
        events: [absent()],
        parentIdsByStudentId: const {},
      );

      expect(signals, isEmpty);
    });

    test('missing student name falls back to a neutral label', () {
      final signal = AbsenceSignalComposer.compose(
        events: [absent(studentName: '   ')],
        parentIdsByStudentId: const {
          's1': ['p1'],
        },
      ).single;

      expect(signal.body, 'تم تسجيل غياب الطالب بتاريخ 03/06/2024');
    });

    test('only the affected student is addressed in a mixed batch', () {
      final signals = AbsenceSignalComposer.compose(
        events: [
          absent(),
          absent(studentId: 's2', studentName: 'خالد'),
        ],
        parentIdsByStudentId: const {
          's2': ['p9'],
        },
      );

      expect(signals, hasLength(1));
      expect(signals.single.audience, 'p9');
      expect(signals.single.body, contains('خالد'));
    });
  });
}
