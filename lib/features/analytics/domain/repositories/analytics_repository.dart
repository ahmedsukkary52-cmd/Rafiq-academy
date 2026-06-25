import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/analytics_entities.dart';

abstract class AnalyticsRepository {
  /// تحليلات حلقة معيّنة (الأرقام + التوزيع + الحضور الأسبوعي)
  Future<Either<Failure, HalaqaAnalyticsEntity>> getHalaqaAnalytics({
    required String halaqaId,
    required DateTime from,
    required DateTime to,
  });

  /// قائمة الطلاب اللي يحتاجون متابعة عاجلة
  Future<Either<Failure, List<AtRiskStudentEntity>>> getAtRiskStudents(
    String halaqaId,
  );

  /// قائمة أفضل الطلاب أداءً
  Future<Either<Failure, List<TopStudentEntity>>> getTopStudents({
    required String halaqaId,
    int limit,
  });
}
