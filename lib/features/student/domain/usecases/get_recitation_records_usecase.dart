import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/recitation_record_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetRecitationRecordsUseCase
    extends UseCase<List<RecitationRecordEntity>, StudentUidParams> {
  final StudentRepository repository;

  GetRecitationRecordsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> call(
    StudentUidParams params,
  ) => repository.getRecitationRecords(params.uid);
}
