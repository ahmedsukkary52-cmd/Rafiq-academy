import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/progress_report_entity.dart';
import '../repositories/progress_report_repository.dart';

class ProgressReportParams {
  final String studentId;

  ProgressReportParams(this.studentId);
}

@injectable
class GetProgressReportUseCase
    extends UseCase<ProgressReportEntity, ProgressReportParams> {
  final ProgressReportRepository repository;

  GetProgressReportUseCase(this.repository);

  @override
  Future<Either<Failure, ProgressReportEntity>> call(
    ProgressReportParams params,
  ) async {
    try {
      return Right(await repository.getReport(studentId: params.studentId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
