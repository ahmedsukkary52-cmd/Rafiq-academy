import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/repositories/teacher_repository.dart';

class AttendanceRecordModel extends AttendanceRecordEntity {
  const AttendanceRecordModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.halaqaId,
    required super.date,
    required super.status,
    required super.recordedBy,
    required super.sessionId,
  });

  factory AttendanceRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final halaqaId = data['halaqaId'] as String? ?? '';
    final rawSession = (data['sessionId'] as String?)?.trim();
    final sessionId = (rawSession != null && rawSession.isNotEmpty)
        ? rawSession
        : AttendancePolicy.sessionIdForDay(halaqaId: halaqaId, day: date);

    return AttendanceRecordModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      halaqaId: halaqaId,
      date: date,
      status: _statusFromString(data['status'] ?? ''),
      recordedBy: data['recordedBy'] ?? '',
      sessionId: sessionId,
    );
  }

  /// The exact status string this record persists — use it whenever a wire
  /// value is needed instead of re-deriving one from the enum.
  String get wireStatus => _statusToString(status);

  Map<String, dynamic> toFirestore() {
    final day = AttendancePolicy.dayStart(date);
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      throw StateError('sessionId is required on every attendance write');
    }
    return {
      'studentId': studentId,
      'studentName': studentName,
      'halaqaId': halaqaId,
      'date': Timestamp.fromDate(day),
      'status': _statusToString(status),
      'recordedBy': recordedBy,
      'sessionId': sid,
    };
  }

  static AttendanceStatus _statusFromString(String v) => switch (v) {
    'present' => AttendanceStatus.present,
    'late' => AttendanceStatus.late,
    'excused' => AttendanceStatus.excused,
    _ => AttendanceStatus.absent,
  };

  static String _statusToString(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => 'present',
    AttendanceStatus.absent => 'absent',
    AttendanceStatus.late => 'late',
    AttendanceStatus.excused => 'excused',
  };
}
