import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../../features/student/domain/entities/halaqa_entity.dart';
import '../../../features/teacher/domain/repositories/teacher_repository.dart';
import 'halaqa_day_readiness.dart';

/// Shared W3/W6 readiness I/O — teacher agenda and supervisor board (H2 / A-H14).
///
/// Owns **no** readiness rules; only loads facts then calls
/// [HalaqaDayReadinessProjector.project].
Future<Either<Failure, HalaqaDayReadiness>> loadHalaqaDayReadiness({
  required TeacherRepository teacherRepository,
  required HalaqaEntity halaqa,
  required DateTime now,
}) async {
  final attendanceEither = await teacherRepository.getHalaqaAttendanceForDate(
    halaqaId: halaqa.id,
    date: now,
  );
  final attendanceFailure = attendanceEither.fold<Failure?>(
    (l) => l,
    (_) => null,
  );
  if (attendanceFailure != null) return Left(attendanceFailure);
  final records = attendanceEither.getOrElse((_) => const []);

  // Skip homework read when roster is empty — same guard as W3/W6
  // (aligns with sendAssignment; projector also ignores homework then).
  DateTime? latestDue;
  final hasRoster = halaqa.studentIds.any((id) => id.trim().isNotEmpty);
  if (hasRoster) {
    final dueEither = await teacherRepository.getLatestAssignmentDueDate(
      halaqa.id,
    );
    final dueFailure = dueEither.fold<Failure?>((l) => l, (_) => null);
    if (dueFailure != null) return Left(dueFailure);
    latestDue = dueEither.getOrElse((_) => null);
  }

  final reviewsEither = await teacherRepository.getHalaqaRecitationRecords(
    halaqa.id,
  );
  final reviewsFailure = reviewsEither.fold<Failure?>((l) => l, (_) => null);
  if (reviewsFailure != null) return Left(reviewsFailure);
  final recitations = reviewsEither.getOrElse((_) => const []);
  final pendingReviewCount = recitations.where((r) => r.isPendingReview).length;

  return Right(
    HalaqaDayReadinessProjector.project(
      rosterStudentIds: halaqa.studentIds,
      markedStudentIds: records.map((r) => r.studentId),
      now: now,
      latestAssignmentDueDate: latestDue,
      pendingReviewCount: pendingReviewCount,
    ),
  );
}
