import '../entities/homework_entity.dart';

class SubmitRecitationParams {
  final String localFilePath;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String halaqaId;
  final String assignmentId;
  final String taskId;
  final String versesRange;
  final int durationSeconds;

  const SubmitRecitationParams({
    required this.localFilePath,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.halaqaId,
    required this.assignmentId,
    required this.taskId,
    required this.versesRange,
    required this.durationSeconds,
  });
}

abstract class HomeworkRepository {
  Future<HomeworkEntity?> getLatestHomework(String studentId);

  Stream<HomeworkEntity?> watchLatestHomework(String studentId);

  Future<HomeworkEntity> toggleTask({
    required String homeworkId,
    required String taskId,
  });

  Future<int> completeHomework(String homeworkId);

  Future<HomeworkEntity> submitRecitation(SubmitRecitationParams params);
}
