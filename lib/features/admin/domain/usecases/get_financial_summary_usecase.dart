import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/financial_summary_entity.dart';
import '../repositories/admin_repository.dart';

class GetFinancialSummaryUseCase
    extends UseCase<FinancialSummaryEntity, NoParams> {
  final AdminRepository repository;

  GetFinancialSummaryUseCase(this.repository);

  @override
  Future<Either<Failure, FinancialSummaryEntity>> call(NoParams params) =>
      repository.getFinancialSummary();
}
