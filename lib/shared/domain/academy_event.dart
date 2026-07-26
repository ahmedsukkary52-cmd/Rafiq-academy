import 'package:equatable/equatable.dart';

import '../utils/attendance_policy.dart';

/// Stable operational facts in the academy.
///
/// Attendance documents remain the SSOT. An [AcademyEvent] is a derived fact
/// that delivery channels (in-app notification, later FCM/SMS/…) may project.
/// Channels never become a second attendance truth.
///
/// W4 implements attendance absence events only. Other event kinds are reserved
/// names for later workflows — do not invent them here until needed.
sealed class AcademyEvent extends Equatable {
  const AcademyEvent();

  /// Deterministic identity of the operational fact (not a delivery message id).
  ///
  /// For absence awareness this is keyed by the attendance document id so
  /// re-saves and corrections address the same fact.
  String get eventId;
}

/// Student transitioned to an explicit `absent` mark for a calendar day.
class StudentAbsentRecorded extends AcademyEvent {
  final String studentId;
  final String studentName;
  final String halaqaId;
  final DateTime date;
  final String attendanceDocumentId;

  const StudentAbsentRecorded({
    required this.studentId,
    required this.studentName,
    required this.halaqaId,
    required this.date,
    required this.attendanceDocumentId,
  });

  @override
  String get eventId => AcademyEventIds.attendanceAbsence(attendanceDocumentId);

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    halaqaId,
    date,
    attendanceDocumentId,
  ];
}

/// Student previously marked explicitly absent was corrected to present/late.
class StudentAbsenceCorrected extends AcademyEvent {
  final String studentId;
  final String studentName;
  final String halaqaId;
  final DateTime date;
  final String attendanceDocumentId;

  /// Wire status after correction: [AttendancePolicy.statusPresent] or
  /// [AttendancePolicy.statusLate].
  final String correctedToStatus;

  const StudentAbsenceCorrected({
    required this.studentId,
    required this.studentName,
    required this.halaqaId,
    required this.date,
    required this.attendanceDocumentId,
    required this.correctedToStatus,
  });

  @override
  String get eventId => AcademyEventIds.attendanceAbsence(attendanceDocumentId);

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    halaqaId,
    date,
    attendanceDocumentId,
    correctedToStatus,
  ];
}

/// Helpers for stable event / per-recipient delivery identities.
class AcademyEventIds {
  const AcademyEventIds._();

  /// One operational absence fact per attendance day document.
  static String attendanceAbsence(String attendanceDocumentId) =>
      'attendance_absence_$attendanceDocumentId';

  /// Per-parent delivery document id for the in-app channel (Slice 1+).
  ///
  /// Keeps channel idempotency without changing the event identity.
  static String inAppDeliveryId({
    required String parentId,
    required String eventId,
  }) => '${parentId}_$eventId';
}
