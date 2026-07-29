import '../../../../shared/domain/academy_event.dart';
import '../../../parent/data/models/parent_model.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../models/attendance_record_model.dart';
import '../models/halaqa_student_summary_model.dart';

abstract class TeacherRemoteDatasource {
  Future<List<HalaqaModel>> getTeacherHalaqat(String teacherId);
  Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents(String halaqaId);
  Future<void> recordAttendance(AttendanceRecordModel record);

  /// Atomic save for a full day register (deterministic doc ids — W2 D8).
  ///
  /// Returns the academy events produced by the **committed** status
  /// transitions. Delivery is not this layer's concern.
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  );
  Future<List<AttendanceRecordModel>> getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  });
  Future<void> addRecitationRecord(RecitationRecordModel record);

  /// Pending → reviewed transition. Returns [HomeworkReviewed] for the
  /// committed fact — no notification writes.
  Future<List<AcademyEvent>> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  });
  Future<List<RecitationRecordModel>> getHalaqaRecitationRecords(
    String halaqaId,
  );

  /// Commits one assignment doc per roster student. Returns [HomeworkAssigned]
  /// facts for the committed docs — no notification writes.
  Future<List<AcademyEvent>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  });

  /// Latest assignment `dueDate` for [halaqaId], or `null` if none exist.
  Future<DateTime?> getLatestAssignmentDueDate(String halaqaId);

  /// Pending استئذان for [halaqaId] (caller filters/auth). Never touches attendance.
  Future<List<AbsenceRequestModel>> getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  });

  /// Status-only review. Never touches attendanceRecords.
  Future<void> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  });
}
