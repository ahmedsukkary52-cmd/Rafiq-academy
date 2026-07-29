import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/halaqa_day_readiness.dart';
import '../../../schedule/data/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../schedule/data/models/halaqa_schedule_source_model.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../read_models/supervisor_day_board.dart';
import '../repositories/parent_repository.dart';

class SupervisorDayBoardParams extends Equatable {
  /// Supervised halaqat already loaded (no extra halaqa list read).
  final List<HalaqaEntity> halaqat;

  /// Injectable clock for deterministic tests. Defaults to [DateTime.now].
  final DateTime? now;

  const SupervisorDayBoardParams({required this.halaqat, this.now});

  @override
  List<Object?> get props => [halaqat, now];
}

/// Builds the supervisor day board from shared readiness facts (W6 Slice 1).
///
/// Owns **no** readiness rules — only:
/// - today's sessions via [HalaqaWeeklySessionsMapper.mapTodayOperationalDays]
/// - operational reads via [TeacherRepository] (existing W1/W2 fact sources)
/// - [HalaqaDayReadinessProjector] for academy facts (D-W6-3 / Rule 5)
/// - teacher display-name enrichment (D-W6-4)
///
/// Does **not** exception-sort (Rule 3 + 5 — presentation). Does **not** invent
/// supervisor attendance/homework/review logic.
@lazySingleton
class GetSupervisorDayBoardUseCase
    extends UseCase<SupervisorDayBoard, SupervisorDayBoardParams> {
  final TeacherRepository teacherRepository;
  final SupervisorRepository supervisorRepository;
  final HalaqaWeeklySessionsMapper _sessionsMapper;

  GetSupervisorDayBoardUseCase({
    required this.teacherRepository,
    required this.supervisorRepository,
  }) : _sessionsMapper = const HalaqaWeeklySessionsMapper();

  @override
  Future<Either<Failure, SupervisorDayBoard>> call(
    SupervisorDayBoardParams params,
  ) async {
    final now = params.now ?? DateTime.now();
    final byId = {for (final h in params.halaqat) h.id: h};

    final days = _sessionsMapper.mapTodayOperationalDays(
      params.halaqat.map(_sourceOf),
      now: now,
    );

    final teacherIds = <String>{};
    for (final day in days) {
      final halaqa = byId[day.halaqaId];
      if (halaqa == null) continue;
      final tid = halaqa.teacherId.trim();
      if (tid.isNotEmpty) teacherIds.add(tid);
    }

    final namesEither = await supervisorRepository.getUserDisplayNames(
      teacherIds.toList(),
    );
    final namesFailure = namesEither.fold<Failure?>((l) => l, (_) => null);
    if (namesFailure != null) return Left(namesFailure);
    final names = namesEither.getOrElse((_) => const <String, String>{});

    final items = <SupervisorDayBoardItem>[];
    for (final day in days) {
      final halaqa = byId[day.halaqaId];
      if (halaqa == null) continue;

      final readinessEither = await _readinessFor(halaqa, now);
      final failure = readinessEither.fold<Failure?>((l) => l, (_) => null);
      if (failure != null) return Left(failure);

      final readiness = readinessEither.getOrElse(
        (_) => HalaqaDayReadiness.complete,
      );
      final teacherId = halaqa.teacherId.trim();

      items.add(
        SupervisorDayBoardItem(
          halaqaId: halaqa.id,
          halaqaName: halaqa.name,
          teacherId: teacherId,
          teacherDisplayName: names[teacherId] ?? '',
          startAt: day.session.startAt,
          readiness: readiness,
        ),
      );
    }

    return Right(
      SupervisorDayBoard(items: items, sessionsTodayCount: days.length),
    );
  }

  Future<Either<Failure, HalaqaDayReadiness>> _readinessFor(
    HalaqaEntity halaqa,
    DateTime now,
  ) async {
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
    final pendingReviewCount = recitations
        .where((r) => r.isPendingReview)
        .length;

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

  HalaqaScheduleSourceModel _sourceOf(HalaqaEntity h) {
    return HalaqaScheduleSourceModel(
      halaqaId: h.id,
      name: h.name,
      meetingLink: h.meetingLink,
      schedule: h.schedule
          .map(
            (s) => HalaqaScheduleSlotModel(
              day: s.day,
              startTime: s.startTime,
              endTime: s.endTime,
            ),
          )
          .toList(),
    );
  }
}
