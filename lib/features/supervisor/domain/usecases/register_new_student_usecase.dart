import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repository.dart';

/// Legacy name retained for DI/tests — implementation is Academy Admission admit.
///
/// Prefer [AdmitStudentToHalaqaUseCase] for new call sites.
@lazySingleton
class RegisterNewStudentUseCase extends UseCase<Unit, AdmitStudentParams> {
  final SupervisorRepository repository;

  RegisterNewStudentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AdmitStudentParams params) =>
      repository.admitStudentToHalaqa(
        supervisorId: params.supervisorId,
        halaqaId: params.halaqaId,
        studentId: params.studentId,
      );
}
