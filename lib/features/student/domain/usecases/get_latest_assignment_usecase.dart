import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/assignment_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetLatestAssignmentUseCase
    extends UseCase<AssignmentEntity?, StudentUidParams> {
  final StudentRepository repository;

  GetLatestAssignmentUseCase(this.repository);

  @override
  Future<Either<Failure, AssignmentEntity?>> call(StudentUidParams params) =>
      repository.getLatestAssignment(params.uid);
}
