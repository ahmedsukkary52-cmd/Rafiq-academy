import '../models/class_session_model.dart';

abstract class ScheduleRemoteDatasource {
  Future<List<ClassSessionModel>> getWeeklySessions();
}
