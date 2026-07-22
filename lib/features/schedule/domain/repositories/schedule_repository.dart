import '../entities/class_session_entity.dart';

abstract class ScheduleRepository {
  Future<List<ClassSessionEntity>> getWeeklySessions();
}
