import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class AddRecitationRecordUseCase extends UseCase<Unit, RecitationRecordEntity> {
  final TeacherRepository repository;

  AddRecitationRecordUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RecitationRecordEntity params) =>
      repository.addRecitationRecord(params);
}
