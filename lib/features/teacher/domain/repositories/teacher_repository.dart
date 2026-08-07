import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../entities/attendance_record_entity.dart';
import '../entities/halaqa_students_summary_entity.dart';

enum AttendanceStatus { present, absent, late, excused }

abstract class TeacherRepository {
  /// الحلقات المسندة للمعلم
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  );

  /// طلاب الحلقة
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  );

  /// تسجيل الحضور لطالب معيّن (upsert لنفس الحلقة/الطالب/اليوم)
  Future<Either<Failure, Unit>> recordAttendance(AttendanceRecordEntity record);

  /// حفظ سجل يوم كامل دفعة واحدة (atomic batch)
  ///
  /// Attendance is the primary operation; the result reports how many academy
  /// events the committed transitions produced and whether they were published.
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> records,
  );

  /// سجلات الحضور لحلقة في يوم معيّن
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  });

  /// تسجيل تقييم التسميع لطالب (auto-id — legacy / non-session paths)
  Future<Either<Failure, Unit>> addRecitationRecord(
    RecitationRecordEntity record,
  );

  /// Upsert teacher live evaluation at deterministic id; retire legacy duplicates.
  Future<Either<Failure, Unit>> upsertTeacherEvaluation({
    required RecitationRecordEntity record,
    required List<String> retireDocumentIds,
  });

  /// مراجعة تسميع معلّق (نفس المستند — لا إنشاء جديد).
  ///
  /// Commits the review then publishes [HomeworkReviewed].
  Future<Either<Failure, AcademyEventPublication>> updateRecitationReview(
    UpdateRecitationReviewParams params,
  );

  /// تقييمات التسميع لحلقة معيّنة
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId);

  /// Commits assignment docs (SSOT) then publishes [HomeworkAssigned] facts.
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  });

  /// Latest assignment `dueDate` for a halaqa (W1 D7 at halaqa scope).
  ///
  /// Returns `null` when the halaqa has no assignments. Used by W3 to derive
  /// "homework assigned for today?" without inventing a second homework rule.
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  );

  /// Pending استئذان for [halaqaId] on [date] (contextual only — no attendance).
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getPendingAbsenceRequests({required String halaqaId, required DateTime date});

  /// Approve/reject request doc only (W7 Rule 1). Never touches attendance.
  Future<Either<Failure, Unit>> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  });
}

class TeacherIdParams extends Equatable {
  final String teacherId;

  const TeacherIdParams(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

class HalaqaStudentsParams extends Equatable {
  final String halaqaId;

  const HalaqaStudentsParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class SendAssignmentParams extends Equatable {
  final String halaqaId;
  final String newMemorizationRange;
  final String reviewRange;
  final DateTime dueDate;
  final String teacherId;

  const SendAssignmentParams({
    required this.halaqaId,
    required this.newMemorizationRange,
    required this.reviewRange,
    required this.dueDate,
    required this.teacherId,
  });

  @override
  List<Object?> get props => [
    halaqaId,
    newMemorizationRange,
    reviewRange,
    dueDate,
    teacherId,
  ];
}

class UpdateRecitationReviewParams extends Equatable {
  final String recordId;
  final String halaqaId;
  final RecitationGrade grade;
  final RecitationGrade behaviorGrade;
  final String? notes;

  const UpdateRecitationReviewParams({
    required this.recordId,
    required this.halaqaId,
    required this.grade,
    required this.behaviorGrade,
    this.notes,
  });

  @override
  List<Object?> get props => [recordId, halaqaId, grade, behaviorGrade, notes];
}
