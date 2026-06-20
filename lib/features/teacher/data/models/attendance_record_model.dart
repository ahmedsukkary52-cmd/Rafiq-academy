import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory AttendanceRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecordModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: _statusFromString(data['status'] ?? ''),
      recordedBy: data['recordedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    'halaqaId': halaqaId,
    'date': Timestamp.fromDate(date),
    'status': _statusToString(status),
    'recordedBy': recordedBy,
  };

  static AttendanceStatus _statusFromString(String v) => switch (v) {
    'present' => AttendanceStatus.present,
    'late' => AttendanceStatus.late,
    _ => AttendanceStatus.absent,
  };

  static String _statusToString(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => 'present',
    AttendanceStatus.absent => 'absent',
    AttendanceStatus.late => 'late',
  };
}
