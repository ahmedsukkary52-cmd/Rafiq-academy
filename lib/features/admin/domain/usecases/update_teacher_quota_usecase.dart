import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class UpdateTeacherQuotaUseCase
    extends UseCase<Unit, UpdateTeacherQuotaParams> {
  final AdminRepository repository;
  UpdateTeacherQuotaUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateTeacherQuotaParams params) =>
      repository.updateTeacherQuota(
        teacherId: params.teacherId,
        weeklyQuota: params.weeklyQuota,
      );
}
