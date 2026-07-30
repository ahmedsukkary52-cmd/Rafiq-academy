import 'package:equatable/equatable.dart';

import '../utils/attendance_policy.dart';

/// Stable operational facts in the academy.
///
/// An [AcademyEvent] is **what happened** — never a notification command.
/// Payload = minimum immutable facts at occurrence time (ids, timestamps,
/// actor, affected entity, workflow fact). No presentation copy.
///
/// Once an event kind is emitted on a live write path it is a **stable
/// contract**: do not rename or change its meaning; evolve by adding a new
/// event kind. Observers must not break because another workflow evolves.
sealed class AcademyEvent extends Equatable {
  const AcademyEvent();

  /// Deterministic identity of the operational fact (not a delivery message id).
  String get eventId;

  /// Subject student of this fact (when the fact is student-scoped).
  String get studentId;
}

/// Student transitioned to an explicit `absent` mark for a calendar day.
///
/// Public since W4 — stable contract. [studentName] was part of the original
/// public payload and must not be removed silently (versioning rule).
class StudentAbsentRecorded extends AcademyEvent {
  @override
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
///
/// Public since W4 — stable contract.
class StudentAbsenceCorrected extends AcademyEvent {
  @override
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

/// Homework (assignment document) was committed for a student.
///
/// Fact only — IDs, actor, due date, assigned ranges. Display names are
/// enriched by delivery/observers when needed.
class HomeworkAssigned extends AcademyEvent {
  final String assignmentId;
  @override
  final String studentId;
  final String halaqaId;
  final String assignedBy;
  final DateTime dueDate;
  final String newMemorizationRange;
  final String reviewRange;

  const HomeworkAssigned({
    required this.assignmentId,
    required this.studentId,
    required this.halaqaId,
    required this.assignedBy,
    required this.dueDate,
    required this.newMemorizationRange,
    required this.reviewRange,
  });

  @override
  String get eventId => AcademyEventIds.homeworkAssigned(assignmentId);

  @override
  List<Object?> get props => [
    assignmentId,
    studentId,
    halaqaId,
    assignedBy,
    dueDate,
    newMemorizationRange,
    reviewRange,
  ];
}

/// A recitation record became reviewed (grade available as academy fact).
///
/// Published from teacher review write path (W5) via [AcademyEventSink].
class HomeworkReviewed extends AcademyEvent {
  final String recitationRecordId;
  @override
  final String studentId;
  final String halaqaId;
  final DateTime date;

  /// Grade strings as stored on the SSOT recitation document.
  final String? grade;
  final String? behaviorGrade;
  final String versesRange;

  const HomeworkReviewed({
    required this.recitationRecordId,
    required this.studentId,
    required this.halaqaId,
    required this.date,
    this.grade,
    this.behaviorGrade,
    this.versesRange = '',
  });

  @override
  String get eventId => AcademyEventIds.homeworkReviewed(recitationRecordId);

  @override
  List<Object?> get props => [
    recitationRecordId,
    studentId,
    halaqaId,
    date,
    grade,
    behaviorGrade,
    versesRange,
  ];
}

/// Deterministic identities of academy facts (not channel message ids).
class AcademyEventIds {
  const AcademyEventIds._();

  /// One operational absence fact per attendance day document.
  static String attendanceAbsence(String attendanceDocumentId) =>
      'attendance_absence_$attendanceDocumentId';

  /// One operational assign fact per assignment document.
  static String homeworkAssigned(String assignmentId) =>
      'homework_assigned_$assignmentId';

  /// One operational review fact per recitation record.
  static String homeworkReviewed(String recitationRecordId) =>
      'homework_reviewed_$recitationRecordId';
}
