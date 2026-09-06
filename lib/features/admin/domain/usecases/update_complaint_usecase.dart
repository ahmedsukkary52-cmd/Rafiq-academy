import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class UpdateComplaintUseCase extends UseCase<Unit, UpdateComplaintParams> {
  final AdminRepository repository;

  UpdateComplaintUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateComplaintParams params) =>
      repository.updateComplaint(
        complaintId: params.complaintId,
        status: params.status,
        priority: params.priority,
        assigneeId: params.assigneeId,
        assigneeRole: params.assigneeRole,
        response: params.response,
      );
}
