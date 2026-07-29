import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/achievement_issue_entity.dart';
import '../entities/supervisor_report_entity.dart';

abstract class SupervisorRepository {
  Future<Either<Failure, List<HalaqaEntity>>> getSupervisedHalaqat(
    String supervisorId,
  );

  Future<Either<Failure, Unit>> issueAchievement(AchievementIssueEntity data);

  Future<Either<Failure, Unit>> submitReport(SupervisorReportEntity report);

  Future<Either<Failure, Unit>> registerNewStudent({
    required String halaqaId,
    required String studentId,
  });

  /// Display names for [userIds] from `users` (W6 D-W6-4).
  ///
  /// Missing users are omitted from the map — callers fall back in presentation.
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  );
}

class SupervisorIdParams extends Equatable {
  final String supervisorId;

  const SupervisorIdParams(this.supervisorId);

  @override
  List<Object?> get props => [supervisorId];
}

class RegisterStudentParams extends Equatable {
  final String halaqaId;
  final String studentId;

  const RegisterStudentParams({
    required this.halaqaId,
    required this.studentId,
  });

  @override
  List<Object?> get props => [halaqaId, studentId];
}
