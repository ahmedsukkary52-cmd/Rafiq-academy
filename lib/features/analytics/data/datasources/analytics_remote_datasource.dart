import '../../domain/entities/analytics_entities.dart';

abstract class AnalyticsRemoteDatasource {
  Future<HalaqaAnalyticsEntity> getHalaqaAnalytics({
    required String halaqaId,
    required DateTime from,
    required DateTime to,
  });

  Future<List<AtRiskStudentEntity>> getAtRiskStudents(String halaqaId);

  Future<List<TopStudentEntity>> getTopStudents({
    required String halaqaId,
    int limit,
  });
}
