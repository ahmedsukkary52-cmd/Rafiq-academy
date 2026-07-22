import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/class_session_entity.dart';
import '../repositories/schedule_repository.dart';

@injectable
class GetWeeklySessionsUseCase
    extends UseCase<List<ClassSessionEntity>, NoParams> {
  final ScheduleRepository repository;

  GetWeeklySessionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ClassSessionEntity>>> call(
    NoParams params,
  ) async {
    try {
      final sessions = await repository.getWeeklySessions();
      return Right(sessions);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
