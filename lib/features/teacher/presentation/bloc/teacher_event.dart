import 'package:equatable/equatable.dart';

import '../../../../shared/domain/evaluation_policy.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/attendance_record_entity.dart';

abstract class TeacherEvent extends Equatable {
  const TeacherEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل الحلقات المسندة للمعلم
class LoadTeacherHalaqatEvent extends TeacherEvent {
  final String teacherId;

  const LoadTeacherHalaqatEvent(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

/// إعادة اشتقاق أجندة اليوم من الحلقات المحمّلة حالياً (W3 — بدون تحميل جديد)
class LoadTodayAgendaEvent extends TeacherEvent {
  const LoadTodayAgendaEvent();
}

/// اختيار حلقة معيّنة من القائمة - بيحمّل طلابها تلقائياً
class SelectHalaqaEvent extends TeacherEvent {
  final String halaqaId;

  const SelectHalaqaEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

/// تحميل طلاب حلقة معيّنة
class LoadHalaqaStudentsEvent extends TeacherEvent {
  final String halaqaId;

  const LoadHalaqaStudentsEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

/// تحميل تقييمات التسميع لحلقة معيّنة
class LoadHalaqaEvaluationsEvent extends TeacherEvent {
  final String halaqaId;

  const LoadHalaqaEvaluationsEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

/// تحميل سجلات الحضور لحلقة في يوم معيّن
class LoadHalaqaAttendanceEvent extends TeacherEvent {
  final String halaqaId;
  final DateTime date;

  const LoadHalaqaAttendanceEvent({required this.halaqaId, required this.date});

  @override
  List<Object?> get props => [halaqaId, date];
}

/// حفظ حضور اليوم لكل الطلاب دفعة واحدة
class SaveDayAttendanceEvent extends TeacherEvent {
  final List<AttendanceRecordEntity> records;

  const SaveDayAttendanceEvent(this.records);

  @override
  List<Object?> get props => [records];
}

/// إرجاع حالة حفظ الحضور لـ idle بعد عرض النتيجة
class ResetAttendanceSubmissionEvent extends TeacherEvent {
  const ResetAttendanceSubmissionEvent();
}

/// تسجيل تقييم تسميع لطالب
class AddRecitationRecordEvent extends TeacherEvent {
  final RecitationRecordEntity record;

  const AddRecitationRecordEvent(this.record);

  @override
  List<Object?> get props => [record];
}

/// Create-or-edit teacher live evaluation (session identity — no duplicates).
class UpsertTeacherEvaluationEvent extends TeacherEvent {
  final EvaluationIdentity identity;
  final DateTime sessionDate;
  final String teacherId;
  final String studentName;
  final RecitationGrade grade;
  final RecitationGrade behaviorGrade;
  final String? notes;

  const UpsertTeacherEvaluationEvent({
    required this.identity,
    required this.sessionDate,
    required this.teacherId,
    required this.studentName,
    required this.grade,
    required this.behaviorGrade,
    this.notes,
  });

  @override
  List<Object?> get props => [
    identity,
    sessionDate,
    teacherId,
    studentName,
    grade,
    behaviorGrade,
    notes,
  ];
}

/// مراجعة تسميع معلّق (تحديث نفس السجل)
class UpdateRecitationReviewEvent extends TeacherEvent {
  final String recordId;
  final String halaqaId;
  final RecitationGrade grade;
  final RecitationGrade behaviorGrade;
  final String? notes;

  const UpdateRecitationReviewEvent({
    required this.recordId,
    required this.halaqaId,
    required this.grade,
    required this.behaviorGrade,
    this.notes,
  });

  @override
  List<Object?> get props => [recordId, halaqaId, grade, behaviorGrade, notes];
}

/// إرجاع حالة إرسال التسميع لـ idle بعد ما الـ UI يعرض النتيجة
class ResetRecitationSubmissionEvent extends TeacherEvent {
  const ResetRecitationSubmissionEvent();
}

/// إرسال تكليف جديد (حفظ ومراجعة) لكل طلاب الحلقة
class SendAssignmentEvent extends TeacherEvent {
  final String halaqaId;
  final String newMemorizationRange;
  final String reviewRange;
  final DateTime dueDate;
  final String teacherId;

  const SendAssignmentEvent({
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

/// إرجاع حالة إرسال التكليف لـ idle بعد ما الـ UI يعرض النتيجة
class ResetAssignmentSubmissionEvent extends TeacherEvent {
  const ResetAssignmentSubmissionEvent();
}

/// Pending استئذان for a halaqa calendar day (W7 Slice 2 — contextual only)
class LoadPendingAbsenceRequestsEvent extends TeacherEvent {
  final String teacherId;
  final String halaqaId;
  final DateTime date;

  const LoadPendingAbsenceRequestsEvent({
    required this.teacherId,
    required this.halaqaId,
    required this.date,
  });

  @override
  List<Object?> get props => [teacherId, halaqaId, date];
}

/// Approve or reject an استئذان (request status only — Rule 1)
class ReviewAbsenceRequestEvent extends TeacherEvent {
  final String requestId;
  final String halaqaId;
  final String teacherId;
  final AbsenceRequestStatus decision;

  const ReviewAbsenceRequestEvent({
    required this.requestId,
    required this.halaqaId,
    required this.teacherId,
    required this.decision,
  });

  @override
  List<Object?> get props => [requestId, halaqaId, teacherId, decision];
}

class ResetAbsenceReviewEvent extends TeacherEvent {
  const ResetAbsenceReviewEvent();
}

/// Clear projection on logout so the next identity cannot inherit state (H1).
class ClearTeacherSessionEvent extends TeacherEvent {
  const ClearTeacherSessionEvent();
}
