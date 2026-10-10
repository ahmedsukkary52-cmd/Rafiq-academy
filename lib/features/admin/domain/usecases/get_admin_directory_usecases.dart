import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/admin_directory_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetAllHalaqatUseCase
    extends UseCase<List<AdminHalaqaSummaryEntity>, NoParams> {
  final AdminRepository repository;

  GetAllHalaqatUseCase(this.repository);

  @override
  Future<Either<Failure, List<AdminHalaqaSummaryEntity>>> call(
    NoParams params,
  ) => repository.getAllHalaqat();
}

@lazySingleton
class GetAllSupervisorsUseCase
    extends UseCase<List<AdminStaffSummaryEntity>, NoParams> {
  final AdminRepository repository;

  GetAllSupervisorsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AdminStaffSummaryEntity>>> call(
    NoParams params,
  ) => repository.getAllSupervisors();
}
