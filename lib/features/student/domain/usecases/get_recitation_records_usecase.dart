import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/recitation_record_entity.dart';
import '../repositories/student_repository.dart';

class GetRecitationRecordsUseCase
    extends UseCase<List<RecitationRecordEntity>, StudentUidParams> {
  final StudentRepository repository;

  GetRecitationRecordsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> call(
    StudentUidParams params,
  ) => repository.getRecitationRecords(params.uid);
}
