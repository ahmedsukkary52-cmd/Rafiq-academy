import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

class ApproveNewStudentUseCase extends UseCase<Unit, ApproveStudentParams> {
  final AdminRepository repository;

  ApproveNewStudentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ApproveStudentParams params) =>
      repository.approveNewStudent(
        studentId: params.studentId,
        halaqaId: params.halaqaId,
      );
}
