import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../domain/entities/progress_report_entity.dart';
import '../../domain/repositories/progress_report_repository.dart';
import '../datasources/progress_report_remote_datasource.dart';
import '../mappers/progress_report_mapper.dart';
import '../models/progress_report_source_model.dart';

@LazySingleton(as: ProgressReportRepository)
class ProgressReportRepositoryImpl implements ProgressReportRepository {
  final ProgressReportRemoteDatasource remoteDatasource;
  final ProgressReportMapper _mapper;

  ProgressReportRepositoryImpl(this.remoteDatasource)
    : _mapper = const ProgressReportMapper();

  static const _lookbackDays = 30;

  @override
  Future<ProgressReportEntity> getReport({required String studentId}) async {
    final id = studentId.trim();
    final now = DateTime.now();
    final endExclusive = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final startInclusive = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: _lookbackDays - 1));

    if (id.isEmpty) {
      return _mapper.map(
        ProgressReportSourceModel(
          studentId: '',
          rangeStart: startInclusive,
          rangeEnd: endExclusive,
          attendance: const [],
          recitations: const [],
        ),
        now: now,
      );
    }

    try {
      final source = await remoteDatasource.getReportSource(
        studentId: id,
        startInclusive: startInclusive,
        endExclusive: endExclusive,
      );
      return _mapper.map(source, now: now);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
