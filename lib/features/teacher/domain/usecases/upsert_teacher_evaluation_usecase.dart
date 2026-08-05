import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/evaluation_policy.dart';
import '../../../../shared/domain/evaluation_service.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../repositories/teacher_repository.dart';

class UpsertTeacherEvaluationParams {
  final EvaluationIdentity identity;
  final DateTime sessionDate;
  final String teacherId;
  final String studentName;
  final RecitationGrade grade;
  final RecitationGrade behaviorGrade;
  final String? notes;
  final List<RecitationRecordEntity> existingRecords;

  const UpsertTeacherEvaluationParams({
    required this.identity,
    required this.sessionDate,
    required this.teacherId,
    required this.studentName,
    required this.grade,
    required this.behaviorGrade,
    required this.existingRecords,
    this.notes,
  });
}

/// Create-or-edit teacher live evaluation via [EvaluationService] uniqueness.
@lazySingleton
class UpsertTeacherEvaluationUseCase
    extends UseCase<Unit, UpsertTeacherEvaluationParams> {
  final TeacherRepository repository;
  final EvaluationService evaluationService;

  UpsertTeacherEvaluationUseCase(this.repository, this.evaluationService);

  @override
  Future<Either<Failure, Unit>> call(UpsertTeacherEvaluationParams params) {
    final plan = evaluationService.planUpsert(
      identity: params.identity,
      records: params.existingRecords,
    );

    final record = RecitationRecordEntity(
      id: plan.documentId,
      studentId: params.identity.studentId,
      studentName: params.studentName,
      teacherId: params.teacherId,
      halaqaId: params.identity.halaqaId,
      date: params.sessionDate,
      type: params.identity.type,
      // Product: versesRange is unused — never collect or validate in UI.
      versesRange: '',
      sessionId: params.identity.sessionId,
      grade: params.grade,
      behaviorGrade: params.behaviorGrade,
      notes: params.notes,
      reviewStatus: 'reviewed',
    );

    return repository.upsertTeacherEvaluation(
      record: record,
      retireDocumentIds: plan.retireDocumentIds,
    );
  }
}
