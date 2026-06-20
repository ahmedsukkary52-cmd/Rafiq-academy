import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class GetTeacherHalaqatUseCase
    extends UseCase<List<HalaqaEntity>, TeacherIdParams> {
  final TeacherRepository repository;

  GetTeacherHalaqatUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> call(TeacherIdParams params) =>
      repository.getTeacherHalaqat(params.teacherId);
}
