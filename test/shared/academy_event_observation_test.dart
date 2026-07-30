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

    test('homework assigned observes subject student and linked parents', () {
      final event = HomeworkAssigned(
        assignmentId: 'a1',
        studentId: 's1',
        halaqaId: 'h1',
        assignedBy: 't1',
        dueDate: date,
        newMemorizationRange: '1-5',
        reviewRange: '',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs, hasLength(2));
      expect(specs[0], isA<SubjectStudentObserver>());
      expect(specs[1], isA<LinkedParentsObserver>());
    });

    test('homework reviewed observes subject student and linked parents', () {
      final event = HomeworkReviewed(
        recitationRecordId: 'r1',
        studentId: 's2',
        halaqaId: 'h1',
        date: date,
        grade: 'جيد',
      );

      final specs = AcademyEventObservation.specsFor(event);

      expect(specs.map((s) => s.runtimeType).toList(), [
        SubjectStudentObserver,
        LinkedParentsObserver,
      ]);
    });
  });

  group('AcademyEventIds', () {
    test('homework fact ids are deterministic', () {
      expect(AcademyEventIds.homeworkAssigned('a1'), 'homework_assigned_a1');
      expect(AcademyEventIds.homeworkReviewed('r1'), 'homework_reviewed_r1');
    });
  });
}
