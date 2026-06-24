import '../../../student/data/models/halaqa_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../models/attendance_record_model.dart';
import '../models/halaqa_student_summary_model.dart';

abstract class TeacherRemoteDatasource {
  Future<List<HalaqaModel>> getTeacherHalaqat(String teacherId);
  Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents(String halaqaId);
  Future<void> recordAttendance(AttendanceRecordModel record);
  Future<void> addRecitationRecord(RecitationRecordModel record);
  Future<void> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  });
}
