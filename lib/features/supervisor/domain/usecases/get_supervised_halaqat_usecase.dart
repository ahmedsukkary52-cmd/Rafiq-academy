import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../repositories/parent_repository.dart';

@lazySingleton
class GetSupervisedHalaqatUseCase
    extends UseCase<List<HalaqaEntity>, SupervisorIdParams> {
  final SupervisorRepository repository;

  GetSupervisedHalaqatUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> call(SupervisorIdParams params) =>
      repository.getSupervisedHalaqat(params.supervisorId);
}
