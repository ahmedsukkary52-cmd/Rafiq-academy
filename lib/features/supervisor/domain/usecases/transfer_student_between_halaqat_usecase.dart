import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repository.dart';

/// Immediate Dual-Halaqa transfer within assigned supervisor scope.
@lazySingleton
class TransferStudentBetweenHalaqatUseCase
    extends UseCase<Unit, TransferStudentParams> {
  final SupervisorRepository repository;

  TransferStudentBetweenHalaqatUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(TransferStudentParams params) =>
      repository.transferStudentBetweenHalaqat(
        supervisorId: params.supervisorId,
        studentId: params.studentId,
        sourceHalaqaId: params.sourceHalaqaId,
        targetHalaqaId: params.targetHalaqaId,
      );
}
