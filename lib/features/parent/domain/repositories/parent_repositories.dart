import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/parent_entities.dart';

abstract class ParentRepository {
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId);

  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  });

  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId);

  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  );

  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  );
}

class ParentIdParams extends Equatable {
  final String parentId;

  const ParentIdParams(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class WeeklyReportParams extends Equatable {
  final String studentId;
  final DateTime weekStart;

  const WeeklyReportParams({required this.studentId, required this.weekStart});

  @override
  List<Object?> get props => [studentId, weekStart];
}
