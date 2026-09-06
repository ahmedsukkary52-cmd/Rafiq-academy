import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/teacher_management_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetAllTeachersUseCase
    extends UseCase<List<TeacherManagementEntity>, NoParams> {
  final AdminRepository repository;
  GetAllTeachersUseCase(this.repository);

  @override
  Future<Either<Failure, List<TeacherManagementEntity>>> call(
    NoParams params,
  ) => repository.getAllTeachers();
}
