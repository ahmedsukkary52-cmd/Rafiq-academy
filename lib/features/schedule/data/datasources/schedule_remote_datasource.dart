import '../models/halaqa_schedule_source_model.dart';

abstract class ScheduleRemoteDatasource {
  /// Reads `halaqat/{halaqaId}` schedule fields only.
  /// Returns null when the document does not exist.
  Future<HalaqaScheduleSourceModel?> getHalaqaScheduleSource(String halaqaId);
}
