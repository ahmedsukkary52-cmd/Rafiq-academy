import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_observation.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  group('AcademyEventObservation', () {
    test('absence facts observe linked parents only', () {
      final event = StudentAbsentRecorded(
        studentId: 's1',
        studentName: 'أحمد',
        halaqaId: 'h1',
        date: date,
        attendanceDocumentId: 'doc1',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs, hasLength(1));
      expect(specs.single, isA<LinkedParentsObserver>());
      expect((specs.single as LinkedParentsObserver).studentId, 's1');
    });

    test('absence correction observes linked parents only', () {
      final event = StudentAbsenceCorrected(
        studentId: 's1',
        studentName: 'أحمد',
        halaqaId: 'h1',
        date: date,
        attendanceDocumentId: 'doc1',
        correctedToStatus: 'present',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs.single, isA<LinkedParentsObserver>());
    });

    test('homework assigned observes subject student and linked parents', () {
      final event = HomeworkAssigned(
        assignmentId: 'a1',
        studentId: 's1',
        studentName: 'أحمد',
        halaqaId: 'h1',
        dueDate: date,
        newMemorizationRange: '1-5',
        reviewRange: '',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs, hasLength(2));
      expect(specs[0], isA<SubjectStudentObserver>());
      expect(specs[1], isA<LinkedParentsObserver>());
      expect((specs[0] as SubjectStudentObserver).studentId, 's1');
      expect((specs[1] as LinkedParentsObserver).studentId, 's1');
    });

    test('homework reviewed observes subject student and linked parents', () {
      final event = HomeworkReviewed(
        recitationRecordId: 'r1',
        studentId: 's2',
        studentName: 'خالد',
        halaqaId: 'h1',
        date: date,
        grade: 'جيد',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs.map((s) => s.runtimeType).toList(), [
        SubjectStudentObserver,
        LinkedParentsObserver,
      ]);
      expect((specs[0] as SubjectStudentObserver).studentId, 's2');
    });
  });

  group('AcademyEventIds', () {
    test(
      'homework fact ids are deterministic and distinct from delivery ids',
      () {
        expect(AcademyEventIds.homeworkAssigned('a1'), 'homework_assigned_a1');
        expect(AcademyEventIds.homeworkReviewed('r1'), 'homework_reviewed_r1');
        expect(
          AcademyEventIds.attendanceAbsence('h1_s1_20240603'),
          'attendance_absence_h1_s1_20240603',
        );
      },
    );
  });
}
