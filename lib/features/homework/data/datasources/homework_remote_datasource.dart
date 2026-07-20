import '../../domain/entities/homework_entity.dart';
import '../../domain/repositories/homework_repository.dart'
    show SubmitRecitationParams;

export '../../domain/repositories/homework_repository.dart'
    show SubmitRecitationParams;

/// مصدر بيانات واجباتي — يقرأ/يكتب في نفس collection `assignments`
/// اللي كارت درس اليوم في Home بيستخدمه.
abstract class HomeworkRemoteDatasource {
  Future<HomeworkEntity?> getLatestHomework(String studentId);

  Stream<HomeworkEntity?> watchLatestHomework(String studentId);

  Future<HomeworkEntity> toggleTask({
    required String homeworkId,
    required String taskId,
  });

  Future<int> completeHomework(String homeworkId);

  /// رفع صوت التسميع + كتابة recitationRecords + تعليم المهمة مكتملة
  Future<HomeworkEntity> submitRecitation(SubmitRecitationParams params);
}
