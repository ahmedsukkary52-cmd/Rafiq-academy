import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/registration_request_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetRegistrationRequestsUseCase
    extends UseCase<List<RegistrationRequestEntity>, NoParams> {
  final AdminRepository repository;

  GetRegistrationRequestsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RegistrationRequestEntity>>> call(
    NoParams params,
  ) => repository.getRegistrationRequests();
}

@lazySingleton
class RejectRegistrationRequestUseCase
    extends UseCase<Unit, RejectRegistrationParams> {
  final AdminRepository repository;

  RejectRegistrationRequestUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RejectRegistrationParams params) =>
      repository.rejectRegistrationRequest(studentId: params.studentId);
}

@lazySingleton
class ApproveRegistrationRequestUseCase
    extends UseCase<Unit, ApproveRegistrationParams> {
  final AdminRepository repository;

  ApproveRegistrationRequestUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ApproveRegistrationParams params) =>
      repository.approveRegistrationRequest(
        studentId: params.studentId,
        halaqaId: params.halaqaId,
        teacherId: params.teacherId,
        supervisorId: params.supervisorId,
      );
}
