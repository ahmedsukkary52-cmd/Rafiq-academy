import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../../core/usecases/usecases.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

class SubmitAbsenceRequestUseCase extends UseCase<Unit, AbsenceRequestEntity> {
  final ParentRepository repository;

  SubmitAbsenceRequestUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AbsenceRequestEntity params) =>
      repository.submitAbsenceRequest(params);
}
