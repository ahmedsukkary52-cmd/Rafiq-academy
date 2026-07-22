import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../entities/homework_entity.dart';
import '../repositories/homework_repository.dart';

@injectable
class GetLatestHomeworkUseCase
    extends UseCase<HomeworkEntity?, StudentUidParams> {
  final HomeworkRepository repository;

  GetLatestHomeworkUseCase(this.repository);

  @override
  Future<Either<Failure, HomeworkEntity?>> call(StudentUidParams params) async {
    try {
      return Right(await repository.getLatestHomework(params.uid));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

@injectable
class WatchLatestHomeworkUseCase
    extends StreamUseCase<HomeworkEntity?, StudentUidParams> {
  final HomeworkRepository repository;

  WatchLatestHomeworkUseCase(this.repository);

  @override
  Stream<Either<Failure, HomeworkEntity?>> call(StudentUidParams params) =>
      repository.watchLatestHomework(params.uid).map(Right.new);
}

class ToggleHomeworkTaskParams {
  final String homeworkId;
  final String taskId;

  ToggleHomeworkTaskParams({required this.homeworkId, required this.taskId});
}

@injectable
class ToggleHomeworkTaskUseCase
    extends UseCase<HomeworkEntity, ToggleHomeworkTaskParams> {
  final HomeworkRepository repository;

  ToggleHomeworkTaskUseCase(this.repository);

  @override
  Future<Either<Failure, HomeworkEntity>> call(
    ToggleHomeworkTaskParams params,
  ) async {
    try {
      return Right(
        await repository.toggleTask(
          homeworkId: params.homeworkId,
          taskId: params.taskId,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

@injectable
class CompleteHomeworkUseCase extends UseCase<int, String> {
  final HomeworkRepository repository;

  CompleteHomeworkUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(String homeworkId) async {
    try {
      return Right(await repository.completeHomework(homeworkId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

@injectable
class SubmitHomeworkRecitationUseCase
    extends UseCase<HomeworkEntity, SubmitRecitationParams> {
  final HomeworkRepository repository;

  SubmitHomeworkRecitationUseCase(this.repository);

  @override
  Future<Either<Failure, HomeworkEntity>> call(
    SubmitRecitationParams params,
  ) async {
    try {
      return Right(await repository.submitRecitation(params));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
