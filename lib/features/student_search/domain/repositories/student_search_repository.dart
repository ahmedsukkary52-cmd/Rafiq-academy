import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/student_search_entry.dart';

/// C13 / WA-14 — read port over the CF-owned student directory projection.
///
/// There is no write method by design: `studentSearch` is materialized by
/// Cloud Functions and Rules deny every client write.
abstract class StudentSearchRepository {
  /// Teacher / Supervisor: students on rosters of halaqat they staff.
  Future<Either<Failure, List<StudentSearchEntry>>> searchInViewerScope({
    required String viewerUid,
    required String query,
    int limit,
  });

  /// Admin: the whole directory, prefix-matched.
  Future<Either<Failure, List<StudentSearchEntry>>> searchAll({
    required String query,
    int limit,
  });

  /// Admin: students of one halaqa, optionally prefix-matched.
  Future<Either<Failure, List<StudentSearchEntry>>> searchInHalaqa({
    required String halaqaId,
    required String query,
    int limit,
  });

  /// Direct identity lookup by the real `studentId`.
  Future<Either<Failure, StudentSearchEntry?>> getByStudentId(String studentId);
}
