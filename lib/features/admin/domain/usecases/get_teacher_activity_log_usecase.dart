import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/teacher_activity_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetTeacherActivityLogUseCase
    extends UseCase<TeacherActivityEntity, TeacherActivityParams> {
  final AdminRepository repository;
  GetTeacherActivityLogUseCase(this.repository);

  @override
  Future<Either<Failure, TeacherActivityEntity>> call(
    TeacherActivityParams params,
  ) => repository.getTeacherActivityLog(
    teacherId: params.teacherId,
    from: params.from,
    to: params.to,
  );
}
