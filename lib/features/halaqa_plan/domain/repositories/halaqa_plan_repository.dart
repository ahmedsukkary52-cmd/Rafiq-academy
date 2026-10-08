import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/halaqa_plan.dart';

abstract class HalaqaPlanRepository {
  /// Read-only projection of the student's lesson homework (assignments SSOT).
  Future<Either<Failure, HalaqaPlan>> getStudentPlan({
    required String studentId,
    String? halaqaId,
  });
}
