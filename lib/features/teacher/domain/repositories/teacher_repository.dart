import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../entities/attendance_record_entity.dart';
import '../entities/halaqa_students_summary_entity.dart';

enum AttendanceStatus { present, absent, late }

abstract class TeacherRepository {
  /// الحلقات المسندة للمعلم
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  );

  /// طلاب الحلقة
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  );

  /// تسجيل الحضور لطالب معيّن
  Future<Either<Failure, Unit>> recordAttendance(AttendanceRecordEntity record);

  /// تسجيل تقييم التسميع لطالب
  Future<Either<Failure, Unit>> addRecitationRecord(
    RecitationRecordEntity record,
  );

  /// إرسال تكليف لطالب أو حلقة كاملة
  Future<Either<Failure, Unit>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  });
}

class TeacherIdParams extends Equatable {
  final String teacherId;

  const TeacherIdParams(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

class HalaqaStudentsParams extends Equatable {
  final String halaqaId;

  const HalaqaStudentsParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class SendAssignmentParams extends Equatable {
  final String halaqaId;
  final String newMemorizationRange;
  final String reviewRange;
  final DateTime dueDate;
  final String teacherId;

  const SendAssignmentParams({
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
