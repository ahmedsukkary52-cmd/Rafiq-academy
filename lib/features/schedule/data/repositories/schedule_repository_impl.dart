import 'package:injectable/injectable.dart';

import '../../domain/entities/class_session_entity.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_remote_datasource.dart';

@LazySingleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDatasource remoteDatasource;

  ScheduleRepositoryImpl(this.remoteDatasource);

  @override
  Future<List<ClassSessionEntity>> getWeeklySessions() {
    return remoteDatasource.getWeeklySessions();
  }
}
