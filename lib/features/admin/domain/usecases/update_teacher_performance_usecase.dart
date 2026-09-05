import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class UpdateTeacherPerformanceUseCase
    extends UseCase<Unit, UpdateTeacherPerformanceParams> {
  final AdminRepository repository;
  UpdateTeacherPerformanceUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateTeacherPerformanceParams params) =>
      repository.updateTeacherPerformance(
        teacherId: params.teacherId,
        rating: params.rating,
      );
}
