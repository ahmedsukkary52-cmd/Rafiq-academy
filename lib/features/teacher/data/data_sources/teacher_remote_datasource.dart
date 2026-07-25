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
  Future<void> saveDayAttendance(List<AttendanceRecordModel> records);
  Future<List<AttendanceRecordModel>> getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  });
  Future<void> addRecitationRecord(RecitationRecordModel record);
  Future<void> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  });
  Future<List<RecitationRecordModel>> getHalaqaRecitationRecords(
    String halaqaId,
  );
  Future<void> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  });
}
