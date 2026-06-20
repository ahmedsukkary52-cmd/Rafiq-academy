import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/halaqa_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetStudentHalaqaUseCase extends UseCase<HalaqaEntity, HalaqaIdParams> {
  final StudentRepository repository;

  GetStudentHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaEntity>> call(HalaqaIdParams params) =>
      repository.getStudentHalaqa(params.halaqaId);
}
