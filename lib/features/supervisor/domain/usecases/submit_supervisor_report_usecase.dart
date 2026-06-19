import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/supervisor_report_entity.dart';
import '../repositories/parent_repository.dart';

class SubmitSupervisorReportUseCase
    extends UseCase<Unit, SupervisorReportEntity> {
  final SupervisorRepository repository;

  SubmitSupervisorReportUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SupervisorReportEntity params) =>
      repository.submitReport(params);
}
