import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/notification_signal_ids.dart';
import 'package:rafiq_academy/features/notifications/domain/services/in_app_academy_signal_composer.dart';
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

  HomeworkAssigned assigned({
    String assignmentId = 'a1',
    String studentId = 's1',
    String range = 'البقرة 1-5',
  }) => HomeworkAssigned(
    assignmentId: assignmentId,
    studentId: studentId,
    studentName: 'أحمد',
    halaqaId: 'h1',
    dueDate: date,
    newMemorizationRange: range,
    reviewRange: '',
  );

  HomeworkReviewed reviewed({
    String recordId = 'r1',
    String? grade = 'ممتاز',
  }) => HomeworkReviewed(
    recitationRecordId: recordId,
    studentId: 's1',
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    grade: grade,
  );

  group('InAppAcademySignalComposer', () {
    test('absence signal carries neutral copy and attendance type', () {
      final event = absent();
      final signals = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      );

      expect(signals, hasLength(1));
      final signal = signals.single;
      expect(signal.audience, 'p1');
      expect(signal.title, 'تم تسجيل غياب');
      expect(signal.body, 'تم تسجيل غياب أحمد بتاريخ 03/06/2024');
      expect(signal.type, NotificationTypes.attendance);
    });

    test('signal id is deterministic per observer and event', () {
      final event = absent();
      final first = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      ).single;
      final again = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      ).single;

      expect(first.id, again.id);
      expect(
        first.id,
        NotificationSignalIds.forObserver(
          observerId: 'p1',
          eventId: event.eventId,
        ),
      );
    });

    test('correction replaces the same message it corrects', () {
      final absenceEvent = absent();
      final correctionEvent = corrected();
      final absence = InAppAcademySignalComposer.compose(
        events: [absenceEvent],
        observerIdsByEventId: {
          absenceEvent.eventId: ['p1'],
        },
      ).single;
      final correction = InAppAcademySignalComposer.compose(
        events: [correctionEvent],
        observerIdsByEventId: {
          correctionEvent.eventId: ['p1'],
        },
      ).single;

      expect(correction.id, absence.id);
      expect(correction.title, 'تم تحديث الحضور');
      expect(correction.body, 'تم تحديث حالة أحمد بتاريخ 03/06/2024 إلى حاضر');
    });

    test('correction to late is worded as late', () {
      final event = corrected(status: 'late');
      final signal = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      ).single;

      expect(signal.body, 'تم تحديث حالة أحمد بتاريخ 03/06/2024 إلى متأخر');
    });

    test('every resolved observer gets an individually addressed signal', () {
      final event = absent();
      final signals = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1', 'p2'],
        },
      );

      expect(signals.map((s) => s.audience), ['p1', 'p2']);
      expect(signals.map((s) => s.id).toSet(), hasLength(2));
    });

    test('no observers produces no signal', () {
      final event = absent();
      final signals = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: const {},
      );

      expect(signals, isEmpty);
    });

    test('missing student name falls back to a neutral label', () {
      final event = absent(studentName: '   ');
      final signal = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      ).single;

      expect(signal.body, 'تم تسجيل غياب الطالب بتاريخ 03/06/2024');
    });

    test('homework assigned uses assignment type and neutral fact copy', () {
      final event = assigned();
      final signals = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['s1', 'p1'],
        },
      );

      expect(signals, hasLength(2));
      expect(signals.map((s) => s.audience), ['s1', 'p1']);
      expect(signals.first.type, NotificationTypes.assignment);
      expect(signals.first.title, 'تكليف جديد');
      expect(signals.first.body, 'تم تعيين تكليف لـ أحمد: البقرة 1-5');
    });

    test('homework reviewed includes grade when present', () {
      final event = reviewed();
      final signal = InAppAcademySignalComposer.compose(
        events: [event],
        observerIdsByEventId: {
          event.eventId: ['p1'],
        },
      ).single;

      expect(signal.type, NotificationTypes.assignment);
      expect(signal.title, 'تم تقييم التسميع');
      expect(signal.body, 'تم تقييم تسميع أحمد: ممتاز');
      expect(signal.id, 'p1_homework_reviewed_r1');
    });
  });
}
