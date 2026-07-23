import '../entities/class_session_entity.dart';

abstract class ScheduleRepository {
  /// Weekly sessions derived from `halaqat/{halaqaId}.schedule`.
  Future<List<ClassSessionEntity>> getWeeklySessions(String halaqaId);
}
