import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetStudentHalaqaUseCase extends UseCase<HalaqaEntity, HalaqaIdParams> {
  final StudentRepository repository;

  GetStudentHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaEntity>> call(HalaqaIdParams params) =>
      repository.getStudentHalaqa(params.halaqaId);
}
