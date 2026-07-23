import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../domain/entities/class_session_entity.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_remote_datasource.dart';
import '../mappers/halaqa_weekly_sessions_mapper.dart';

@LazySingleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDatasource remoteDatasource;
  final HalaqaWeeklySessionsMapper _mapper;

  ScheduleRepositoryImpl(this.remoteDatasource)
    : _mapper = const HalaqaWeeklySessionsMapper();

  @override
  Future<List<ClassSessionEntity>> getWeeklySessions(String halaqaId) async {
    final id = halaqaId.trim();
    if (id.isEmpty) return const [];

    final source = await remoteDatasource.getHalaqaScheduleSource(id);
    if (source == null) {
      throw const ServerException('الحلقة غير موجودة');
    }
    return _mapper.map(source);
  }
}
