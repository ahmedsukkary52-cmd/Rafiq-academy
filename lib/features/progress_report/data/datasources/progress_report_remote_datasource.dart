import '../models/progress_report_source_model.dart';

abstract class ProgressReportRemoteDatasource {
  /// Reads attendance + recitation docs for [studentId] in [startInclusive, endExclusive).
  Future<ProgressReportSourceModel> getReportSource({
    required String studentId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  });
}
