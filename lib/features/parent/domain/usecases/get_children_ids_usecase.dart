import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetChildrenIdsUseCase extends UseCase<List<String>, ParentIdParams> {
  final ParentRepository repository;

  GetChildrenIdsUseCase(this.repository);

  @override
  Future<Either<Failure, List<String>>> call(ParentIdParams params) =>
      repository.getChildrenIds(params.parentId);
}
