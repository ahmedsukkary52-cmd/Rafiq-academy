import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/admin_halaqa_roster_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetAcademyStudentRosterUseCase
    extends UseCase<List<AdminHalaqaRosterEntity>, NoParams> {
  final AdminRepository repository;

  GetAcademyStudentRosterUseCase(this.repository);

  @override
  Future<Either<Failure, List<AdminHalaqaRosterEntity>>> call(
    NoParams params,
  ) => repository.getAcademyStudentRoster();
}
