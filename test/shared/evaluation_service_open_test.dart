import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/evaluation_policy.dart';
import 'package:rafiq_academy/shared/domain/evaluation_service.dart';

void main() {
  const service = EvaluationService();
  const halaqaId = 'halaqa1';
  const sessionId = 'halaqa1_20260805';
  const studentId = 'student1';

  // Wednesday 2026-08-05
  final wednesday = DateTime(2026, 8, 5, 10);

  HalaqaEntity halaqaWithWednesday() => const HalaqaEntity(
        id: halaqaId,
        name: 'حلقة',
        teacherId: 't1',
        supervisorId: 's1',
        studentIds: [studentId],
        schedule: [
          HalaqaScheduleEntity(
            day: 'الأربعاء',
            startTime: '10:00',
            endTime: '11:00',
          ),
        ],
        meetingLink: '',
        status: 'active',
      );

  RecitationRecordEntity memRecord({
    required String id,
    String? sessionIdField,
  }) {
    return RecitationRecordEntity(
      id: id,
      studentId: studentId,
      studentName: 'طالب',
      teacherId: 't1',
      halaqaId: halaqaId,
      date: DateTime(2026, 8, 5),
      type: RecitationType.memorization,
      versesRange: '',
      sessionId: sessionIdField,
      grade: RecitationGrade.excellent,
      behaviorGrade: RecitationGrade.veryGood,
      notes: 'ملاحظة',
      reviewStatus: 'reviewed',
    );
  }

  test('openEvaluation without student → create ready model for today', () {
    final result = service.openEvaluation(
      halaqaId: halaqaId,
      halaqa: halaqaWithWednesday(),
      records: const [],
      now: wednesday,
    );
    expect(result.isReady, isTrue);
    final model = result.model!;
    expect(model.mode, EvaluationSheetMode.create);
    expect(model.sessionId, sessionId);
    expect(model.identity, isNull);
    expect(model.identityLocked, isFalse);
  });

  test('openEvaluation with existing identity → edit and prefill', () {
    final preferred = EvaluationPolicy.documentId(
      EvaluationIdentity(
        sessionId: sessionId,
        halaqaId: halaqaId,
        studentId: studentId,
        type: RecitationType.memorization,
      ),
    );
    final existing = memRecord(id: preferred, sessionIdField: sessionId);
    final result = service.openEvaluation(
      halaqaId: halaqaId,
      halaqa: halaqaWithWednesday(),
      records: [existing],
      studentId: studentId,
      type: RecitationType.memorization,
      now: wednesday,
    );
    expect(result.isReady, isTrue);
    final model = result.model!;
    expect(model.mode, EvaluationSheetMode.edit);
    expect(model.identity?.studentId, studentId);
    expect(model.typeGrade, RecitationGrade.excellent);
    expect(model.behaviorGrade, RecitationGrade.veryGood);
    expect(model.notes, 'ملاحظة');
  });

  test('openEvaluation from existingRecord locks identity', () {
    final preferred = EvaluationPolicy.documentId(
      EvaluationIdentity(
        sessionId: sessionId,
        halaqaId: halaqaId,
        studentId: studentId,
        type: RecitationType.memorization,
      ),
    );
    final existing = memRecord(id: preferred, sessionIdField: sessionId);
    final result = service.openEvaluation(
      halaqaId: halaqaId,
      records: [existing],
      existingRecord: existing,
    );
    expect(result.isReady, isTrue);
    expect(result.model!.identityLocked, isTrue);
    expect(result.model!.mode, EvaluationSheetMode.edit);
  });

  test('openEvaluation blocks when no session today', () {
    final thursday = DateTime(2026, 8, 6, 10);
    final result = service.openEvaluation(
      halaqaId: halaqaId,
      halaqa: halaqaWithWednesday(),
      records: const [],
      now: thursday,
    );
    expect(result.isReady, isFalse);
    expect(
      result.blockReason,
      OpenEvaluationBlockReason.noSessionToday,
    );
  });

  test('openEvaluation blocks when halaqa missing for today path', () {
    final result = service.openEvaluation(
      halaqaId: halaqaId,
      records: const [],
    );
    expect(
      result.blockReason,
      OpenEvaluationBlockReason.halaqaUnavailable,
    );
  });
}
