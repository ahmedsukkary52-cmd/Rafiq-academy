import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repository.dart';

/// Supervisor entry into **Academy Admission Workflow** for an existing student.
///
/// Does not create user/guardian/documents. Does not use a partial roster write.
@lazySingleton
class AdmitStudentToHalaqaUseCase extends UseCase<Unit, AdmitStudentParams> {
  final SupervisorRepository repository;

  AdmitStudentToHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AdmitStudentParams params) =>
      repository.admitStudentToHalaqa(
        supervisorId: params.supervisorId,
        halaqaId: params.halaqaId,
        studentId: params.studentId,
      );
}
