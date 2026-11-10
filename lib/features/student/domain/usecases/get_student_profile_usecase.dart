import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/student_profile_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetStudentProfileUseCase
    extends UseCase<StudentProfileEntity, StudentUidParams> {
  final StudentRepository repository;

  GetStudentProfileUseCase(this.repository);

  @override
  Future<Either<Failure, StudentProfileEntity>> call(StudentUidParams params) =>
      repository.getStudentProfile(params.uid);
}
