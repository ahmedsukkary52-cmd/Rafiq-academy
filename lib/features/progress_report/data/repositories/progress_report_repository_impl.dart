import 'package:injectable/injectable.dart';

import '../../domain/entities/progress_report_entity.dart';
import '../../domain/repositories/progress_report_repository.dart';
import '../datasources/progress_report_remote_datasource.dart';

@LazySingleton(as: ProgressReportRepository)
class ProgressReportRepositoryImpl implements ProgressReportRepository {
  final ProgressReportRemoteDatasource remoteDatasource;

  ProgressReportRepositoryImpl(this.remoteDatasource);

  @override
  Future<ProgressReportEntity> getReport({required String studentId}) =>
      remoteDatasource.getReport(studentId: studentId);
}
