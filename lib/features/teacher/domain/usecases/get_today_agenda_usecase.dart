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
import '../read_models/teacher_day_agenda.dart';
import '../repositories/teacher_repository.dart';

class TodayAgendaParams extends Equatable {
  /// Teacher's halaqat, already loaded by the dashboard flow (no extra read).
  final List<HalaqaEntity> halaqat;

  /// Injectable clock for deterministic tests. Defaults to [DateTime.now].
  final DateTime? now;

  const TodayAgendaParams({required this.halaqat, this.now});

  @override
  List<Object?> get props => [halaqat, now];
}

/// W3 application orchestrator: determine today's work → determine readiness.
///
/// Owns **no** business rules. It only:
/// - asks [HalaqaWeeklySessionsMapper.mapTodayOperationalDays] for today's
///   halaqat in D6/D7 order,
/// - asks [loadHalaqaDayReadiness] / [HalaqaDayReadinessProjector] for the
///   three W3 pillars (W6 D-W6-3),
/// - maps explainable gaps to [TeacherAgendaAction] for the teacher UI.
///
/// Navigation stays in the widget. [TeacherDayAgenda] is a read projection.
@lazySingleton
class GetTodayAgendaUseCase
    extends UseCase<TeacherDayAgenda, TodayAgendaParams> {
  final TeacherRepository repository;
  final HalaqaWeeklySessionsMapper _sessionsMapper;

  GetTodayAgendaUseCase(this.repository)
    : _sessionsMapper = const HalaqaWeeklySessionsMapper();

  @override
  Future<Either<Failure, TeacherDayAgenda>> call(
    TodayAgendaParams params,
  ) async {
    final now = params.now ?? DateTime.now();
    final byId = {for (final h in params.halaqat) h.id: h};

    // 1. Today's operational days — D6/D7 owned by the Pre-Slice mapper.
    final days = _sessionsMapper.mapTodayOperationalDays(
      params.halaqat.map(halaqaScheduleSourceFromEntity),
      now: now,
    );

    // 2. Readiness per halaqa; keep only halaqat with remaining work.
    final items = <TeacherAgendaItem>[];
    for (final day in days) {
      final halaqa = byId[day.halaqaId];
      if (halaqa == null) continue;

      final readinessEither = await loadHalaqaDayReadiness(
        teacherRepository: repository,
        halaqa: halaqa,
        now: now,
      );
      final failure = readinessEither.fold<Failure?>((l) => l, (_) => null);
      if (failure != null) return Left(failure);

      final readiness = readinessEither.getOrElse(
        (_) => HalaqaDayReadiness.complete,
      );
      if (readiness.isComplete) continue;

      items.add(
        TeacherAgendaItem(
          halaqaId: halaqa.id,
          halaqaName: halaqa.name,
          startAt: day.session.startAt,
          pendingActions: readiness.gaps.map(_actionFor).toList(),
        ),
      );
    }

    return Right(
      TeacherDayAgenda(items: items, sessionsTodayCount: days.length),
    );
  }

  TeacherAgendaAction _actionFor(HalaqaDayGap gap) => switch (gap.kind) {
    HalaqaDayGapKind.attendanceIncomplete => TeacherAgendaAction.takeAttendance,
    HalaqaDayGapKind.homeworkPending => TeacherAgendaAction.sendHomework,
    HalaqaDayGapKind.reviewsPending => TeacherAgendaAction.reviewRecitations,
  };
}
