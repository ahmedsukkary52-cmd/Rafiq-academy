import 'package:injectable/injectable.dart';

import '../../domain/entities/homework_entity.dart';
import '../../domain/repositories/homework_repository.dart';
import '../datasources/homework_remote_datasource.dart';

@LazySingleton(as: HomeworkRepository)
class HomeworkRepositoryImpl implements HomeworkRepository {
  final HomeworkRemoteDatasource remoteDatasource;

  HomeworkRepositoryImpl(this.remoteDatasource);

  @override
  Future<HomeworkEntity?> getLatestHomework(String studentId) =>
      remoteDatasource.getLatestHomework(studentId);

  @override
  Stream<HomeworkEntity?> watchLatestHomework(String studentId) =>
      remoteDatasource.watchLatestHomework(studentId);

  @override
  Future<HomeworkEntity> toggleTask({
    required String homeworkId,
    required String taskId,
  }) => remoteDatasource.toggleTask(homeworkId: homeworkId, taskId: taskId);

  @override
  Future<int> completeHomework(String homeworkId) =>
      remoteDatasource.completeHomework(homeworkId);

  @override
  Future<HomeworkEntity> submitRecitation(SubmitRecitationParams params) =>
      remoteDatasource.submitRecitation(params);
}
