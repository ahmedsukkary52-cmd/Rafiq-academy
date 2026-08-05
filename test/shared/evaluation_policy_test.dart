import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/evaluation_policy.dart';

void main() {
  const sessionId = 'halaqa1_20260805';
  const halaqaId = 'halaqa1';
  const studentId = 'student1';

  EvaluationIdentity identity(RecitationType type) => EvaluationIdentity(
        sessionId: sessionId,
        halaqaId: halaqaId,
        studentId: studentId,
        type: type,
      );

  RecitationRecordEntity record({
    required String id,
    RecitationType type = RecitationType.memorization,
    String? sessionIdField,
    DateTime? date,
    String? assignmentId,
    String reviewStatus = 'reviewed',
  }) {
    return RecitationRecordEntity(
      id: id,
      studentId: studentId,
      studentName: 'طالب',
      teacherId: 'teacher1',
      halaqaId: halaqaId,
      date: date ?? DateTime(2026, 8, 5),
      type: type,
      versesRange: '',
      sessionId: sessionIdField,
      grade: RecitationGrade.good,
      behaviorGrade: RecitationGrade.good,
      assignmentId: assignmentId,
      reviewStatus: reviewStatus,
    );
  }

  test('documentId encodes session + student + type', () {
    expect(
      EvaluationPolicy.documentId(identity(RecitationType.memorization)),
      'halaqa1_20260805_student1_memorization',
    );
    expect(
      EvaluationPolicy.documentId(identity(RecitationType.review)),
      'halaqa1_20260805_student1_review',
    );
  });

  test('sessionIdForDay matches operational day shape', () {
    expect(
      EvaluationPolicy.sessionIdForDay(
        halaqaId: halaqaId,
        day: DateTime(2026, 8, 5),
      ),
      sessionId,
    );
  });

  test('resolveOpen → create when none exists', () {
    final decision = EvaluationPolicy.resolveOpen(
      identity: identity(RecitationType.memorization),
      records: const [],
    );
    expect(decision.mode, EvaluationSheetMode.create);
    expect(decision.existing, isNull);
  });

  test('resolveOpen → edit when identity matches', () {
    final preferred = EvaluationPolicy.documentId(
      identity(RecitationType.memorization),
    );
    final existing = record(id: preferred, sessionIdField: sessionId);
    final decision = EvaluationPolicy.resolveOpen(
      identity: identity(RecitationType.memorization),
      records: [existing],
    );
    expect(decision.mode, EvaluationSheetMode.edit);
    expect(decision.existing, existing);
  });

  test('planUpsert retires legacy duplicate ids', () {
    final preferred = EvaluationPolicy.documentId(
      identity(RecitationType.memorization),
    );
    final legacy = record(
      id: 'auto-legacy-id',
      sessionIdField: null,
      date: DateTime(2026, 8, 5),
    );
    final plan = EvaluationPolicy.planUpsert(
      identity: identity(RecitationType.memorization),
      records: [legacy],
    );
    expect(plan.documentId, preferred);
    expect(plan.mode, EvaluationSheetMode.edit);
    expect(plan.retireDocumentIds, ['auto-legacy-id']);
  });

  test('pending homework submissions are not session-scoped matches', () {
    final pending = record(
      id: 'pending1',
      reviewStatus: 'pending',
      assignmentId: 'asg1',
      sessionIdField: sessionId,
    );
    final found = EvaluationPolicy.findExisting(
      identity: identity(RecitationType.memorization),
      records: [pending],
    );
    expect(found, isNull);
  });

  test('memorization and review are distinct identities', () {
    final memId = EvaluationPolicy.documentId(
      identity(RecitationType.memorization),
    );
    final mem = record(id: memId, sessionIdField: sessionId);
    final found = EvaluationPolicy.findExisting(
      identity: identity(RecitationType.review),
      records: [mem],
    );
    expect(found, isNull);
  });
}
