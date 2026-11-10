import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import 'attendance_record_entity.dart';
import 'halaqa_entity.dart';
import 'halaqa_day_facts.dart';
import 'halaqa_day_readiness.dart';
import 'recitation_record_entity.dart';

/// The Halaqa-day reads readiness needs (attendance, homework, reviews).
abstract interface class HalaqaDayFactsReader {
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  });

  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  );

  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId);
}

/// Shared W3/W6 readiness I/O — teacher agenda and supervisor board (H2 / A-H14).
///
/// Owns **no** readiness rules; only loads facts then calls
/// [HalaqaDayReadinessProjector.project].
Future<Either<Failure, HalaqaDayReadiness>> loadHalaqaDayReadiness({
  required HalaqaDayFactsReader teacherRepository,
  required HalaqaEntity halaqa,
  required DateTime now,
}) async {
  final factsEither = await loadHalaqaDayFacts(
    teacherRepository: teacherRepository,
    halaqa: halaqa,
    now: now,
  );
  return factsEither.map((facts) => facts.readiness);
}

/// Same Firestore reads as readiness, but keeps attendance + recitation rows
/// so Teacher Home can project recent activities without a second pass.
Future<Either<Failure, HalaqaDayFacts>> loadHalaqaDayFacts({
  required HalaqaDayFactsReader teacherRepository,
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

  final readiness = HalaqaDayReadinessProjector.project(
    rosterStudentIds: halaqa.studentIds,
    markedStudentIds: records.map((r) => r.studentId),
    now: now,
    latestAssignmentDueDate: latestDue,
    pendingReviewCount: pendingReviewCount,
  );

  return Right(
    HalaqaDayFacts(
      readiness: readiness,
      attendance: records,
      recitations: recitations,
    ),
  );
}
