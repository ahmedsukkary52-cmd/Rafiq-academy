import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/class_session_entity.dart';
import '../repositories/schedule_repository.dart';

class WeeklySessionsParams {
  final String halaqaId;

  const WeeklySessionsParams(this.halaqaId);
}

@injectable
class GetWeeklySessionsUseCase
    extends UseCase<List<ClassSessionEntity>, WeeklySessionsParams> {
  final ScheduleRepository repository;

  GetWeeklySessionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ClassSessionEntity>>> call(
    WeeklySessionsParams params,
  ) async {
    try {
      final sessions = await repository.getWeeklySessions(params.halaqaId);
      return Right(sessions);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
