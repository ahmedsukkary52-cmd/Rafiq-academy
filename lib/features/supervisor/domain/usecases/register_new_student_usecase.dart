import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repository.dart';

class RegisterNewStudentUseCase extends UseCase<Unit, RegisterStudentParams> {
  final SupervisorRepository repository;

  RegisterNewStudentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RegisterStudentParams params) =>
      repository.registerNewStudent(
        halaqaId: params.halaqaId,
        studentId: params.studentId,
      );
}
