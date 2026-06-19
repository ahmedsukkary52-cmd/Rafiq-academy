import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

class RespondToComplaintUseCase extends UseCase<Unit, RespondComplaintParams> {
  final AdminRepository repository;

  RespondToComplaintUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RespondComplaintParams params) =>
      repository.respondToComplaint(
        complaintId: params.complaintId,
        response: params.response,
      );
}
