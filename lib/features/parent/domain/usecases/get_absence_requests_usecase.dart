import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetAbsenceRequestsUseCase
    extends UseCase<List<AbsenceRequestEntity>, ParentIdParams> {
  final ParentRepository repository;

  GetAbsenceRequestsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>> call(
    ParentIdParams params,
  ) => repository.getAbsenceRequestsForParent(params.parentId);
}
