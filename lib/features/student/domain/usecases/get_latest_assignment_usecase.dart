import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/assignment_entity.dart';
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
