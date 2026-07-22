import '../entities/progress_report_entity.dart';

abstract class ProgressReportRepository {
  Future<ProgressReportEntity> getReport({required String studentId});
}
