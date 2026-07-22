import 'package:equatable/equatable.dart';

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

/// تسجيل حضور/غياب/تأخير لطالب بنقرة واحدة.
/// بيتعمل لها Optimistic Update فوراً في الـ UI قبل ما الكتابة في
/// Firestore تخلص، عشان الاستجابة تكون فورية للمعلم.
class RecordAttendanceEvent extends TeacherEvent {
  final AttendanceRecordEntity record;

  const RecordAttendanceEvent(this.record);

  @override
  List<Object?> get props => [record];
}

/// تحميل سجلات الحضور لحلقة في يوم معيّن
class LoadHalaqaAttendanceEvent extends TeacherEvent {
  final String halaqaId;
  final DateTime date;

  const LoadHalaqaAttendanceEvent({
    required this.halaqaId,
    required this.date,
  });

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
