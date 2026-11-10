import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/halaqa_roster.dart';
import '../../../../shared/domain/recitation_record_entity.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class GetHalaqaRecitationRecordsUseCase
    extends UseCase<List<RecitationRecordEntity>, HalaqaStudentsParams> {
  final TeacherRepository repository;

  GetHalaqaRecitationRecordsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> call(
    HalaqaStudentsParams params,
  ) => repository.getHalaqaRecitationRecords(params.halaqaId);
}
