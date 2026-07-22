import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
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
