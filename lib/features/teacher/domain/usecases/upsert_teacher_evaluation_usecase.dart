import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/evaluation_policy.dart';
import '../../../../shared/domain/evaluation_service.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../entities/attendance_record_entity.dart';
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
///
/// D7: the student must be marked Present or Late for the same session.
/// The upsertSessionEvaluation callable enforces this transactionally; this
/// check only turns a rejected call into a clear message early.
@lazySingleton
class UpsertTeacherEvaluationUseCase
    extends UseCase<Unit, UpsertTeacherEvaluationParams> {
  final TeacherRepository repository;
  final EvaluationService evaluationService;

  UpsertTeacherEvaluationUseCase(this.repository, this.evaluationService);

  static const String notAttendedMessage =
      'لا يمكن تقييم الطالب إلا بعد تسجيل حضوره (حاضر أو متأخر) في هذه الجلسة';

  @override
  Future<Either<Failure, Unit>> call(
    UpsertTeacherEvaluationParams params,
  ) async {
    final attendance = await repository.getHalaqaAttendanceForDate(
      halaqaId: params.identity.halaqaId,
      date: params.sessionDate,
    );
    return attendance.fold(Left.new, (marks) {
      if (!_attendedSession(marks, params.identity)) {
        return const Left(ValidationFailure(notAttendedMessage));
      }
      return _upsert(params);
    });
  }

  static bool _attendedSession(
    List<AttendanceRecordEntity> marks,
    EvaluationIdentity identity,
  ) {
    final studentId = identity.studentId.trim();
    return marks.any(
      (m) =>
          m.studentId.trim() == studentId &&
          AttendancePolicy.belongsToSession(
            recordSessionId: m.sessionId,
            recordHalaqaId: m.halaqaId,
            recordDate: m.date,
            sessionId: identity.sessionId,
            halaqaId: identity.halaqaId,
          ) &&
          (m.status == AttendanceStatus.present ||
              m.status == AttendanceStatus.late),
    );
  }

  Future<Either<Failure, Unit>> _upsert(UpsertTeacherEvaluationParams params) {
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
