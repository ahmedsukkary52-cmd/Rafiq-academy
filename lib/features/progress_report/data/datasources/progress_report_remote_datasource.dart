import '../../domain/entities/progress_report_entity.dart';

abstract class ProgressReportRemoteDatasource {
  Future<ProgressReportEntity> getReport({required String studentId});
}
