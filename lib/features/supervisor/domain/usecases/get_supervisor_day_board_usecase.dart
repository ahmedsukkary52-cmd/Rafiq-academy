import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/halaqa_day_readiness.dart';
import '../../../../shared/domain/load_halaqa_day_readiness.dart';
import '../../../schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../../schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
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
/// - operational reads via [loadHalaqaDayReadiness] (shared with W3)
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
      params.halaqat.map(halaqaScheduleSourceFromEntity),
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

      final readinessEither = await loadHalaqaDayReadiness(
        teacherRepository: teacherRepository,
        halaqa: halaqa,
        now: now,
      );
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
}
