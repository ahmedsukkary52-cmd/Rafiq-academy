import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/achievement_issue_entity.dart';
import '../entities/payment_review_params.dart';
import '../entities/supervisor_report_entity.dart';

abstract class SupervisorRepository {
  Future<Either<Failure, List<HalaqaEntity>>> getSupervisedHalaqat(
    String supervisorId,
  );

  Future<Either<Failure, Unit>> issueAchievement(AchievementIssueEntity data);

  Future<Either<Failure, Unit>> submitReport(SupervisorReportEntity report);

  /// Academy Admission entry for an existing student into a supervised halaqa.
  Future<Either<Failure, Unit>> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  });

  Future<Either<Failure, Unit>> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  });

  /// Display names for [userIds] from `users` (W6 D-W6-4).
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  );

  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  });

  /// Payments for students in supervised halaqat (chunked `whereIn`).
  Future<Either<Failure, List<PaymentEntity>>> getPaymentsForStudents({
    required String supervisorId,
    required List<String> studentIds,
  });

  Future<Either<Failure, Unit>> reviewPaymentProof(PaymentReviewParams params);
}

class SupervisorIdParams extends Equatable {
  final String supervisorId;

  const SupervisorIdParams(this.supervisorId);

  @override
  List<Object?> get props => [supervisorId];
}

class AdmitStudentParams extends Equatable {
  final String supervisorId;
  final String halaqaId;
  final String studentId;

  const AdmitStudentParams({
    required this.supervisorId,
    required this.halaqaId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [supervisorId, halaqaId, studentId];
}

class TransferStudentParams extends Equatable {
  final String supervisorId;
  final String studentId;
  final String sourceHalaqaId;
  final String targetHalaqaId;

  const TransferStudentParams({
    required this.supervisorId,
    required this.studentId,
    required this.sourceHalaqaId,
    required this.targetHalaqaId,
  });

  @override
  List<Object?> get props => [
    supervisorId,
    studentId,
    sourceHalaqaId,
    targetHalaqaId,
  ];
}
