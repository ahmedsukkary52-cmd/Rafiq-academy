import '../../domain/entities/parent_entities.dart';

export '../../../../shared/data/absence_request_model.dart';
export '../../../../shared/data/models/payment_model.dart';

class WeeklyReportModel extends WeeklyReportEntity {
  const WeeklyReportModel({
    required super.studentId,
    required super.studentName,
    required super.weekStart,
    required super.totalVersesMemorized,
    required super.attendedSessions,
    required super.totalSessions,
    required super.teacherNotes,
  });

  factory WeeklyReportModel.fromMap({
    required String studentId,
    required String studentName,
    required DateTime weekStart,
    required Map<String, dynamic> data,
  }) {
    return WeeklyReportModel(
      studentId: studentId,
      studentName: studentName,
      weekStart: weekStart,
      totalVersesMemorized: (data['totalVersesMemorized'] ?? 0) as int,
      attendedSessions: (data['attendedSessions'] ?? 0) as int,
      totalSessions: (data['totalSessions'] ?? 0) as int,
      teacherNotes: data['teacherNotes'] ?? '',
    );
  }
}
