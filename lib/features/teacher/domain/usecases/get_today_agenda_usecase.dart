import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../schedule/data/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../schedule/data/models/halaqa_schedule_source_model.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/attendance_record_entity.dart';
import '../entities/teacher_day_agenda.dart';
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

/// W3 orchestration use case: **determine today's work → determine readiness**.
///
/// Navigation itself happens in the widget. This layer never re-implements a
/// business rule — it reuses:
/// - [HalaqaWeeklySessionsMapper.mapTodayOperationalDays] for D6/D7 day derivation
///   (day boundaries via `AttendancePolicy`, so W2 stays the single source),
/// - existing W2 attendance reads for register readiness,
/// - existing W1 recitation reads + [RecitationRecordEntity.isPendingReview]
///   for pending-review readiness.
///
/// Homework-assigned readiness is intentionally out of Slice 1 (it needs a new
/// halaqa-scoped assignment query/index — handled in Slice 2).
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

    // 1. Which halaqat meet today, in stable execution order (D6/D7).
    final operational = <(HalaqaEntity, DateTime)>[];
    for (final halaqa in params.halaqat) {
      final days = _sessionsMapper.mapTodayOperationalDays([
        _sourceOf(halaqa),
      ], now: now);
      if (days.isEmpty) continue;
      operational.add((halaqa, days.first.startAt));
    }
    operational.sort((a, b) {
      final byTime = a.$2.compareTo(b.$2);
      if (byTime != 0) return byTime;
      return a.$1.id.compareTo(b.$1.id); // D7 stable fallback: halaqa id.
    });

    // 2. Readiness per halaqa; keep only halaqat with remaining work.
    final items = <TeacherAgendaItem>[];
    for (final (halaqa, startAt) in operational) {
      final actionsEither = await _pendingActionsFor(halaqa, now);
      final failure = actionsEither.fold<Failure?>((l) => l, (_) => null);
      if (failure != null) return Left(failure);

      final actions = actionsEither.getOrElse((_) => const []);
      if (actions.isEmpty) continue;

      items.add(
        TeacherAgendaItem(
          halaqaId: halaqa.id,
          halaqaName: halaqa.name,
          startAt: startAt,
          pendingActions: actions,
        ),
      );
    }

    return Right(
      TeacherDayAgenda(items: items, sessionsTodayCount: operational.length),
    );
  }

  Future<Either<Failure, List<TeacherAgendaAction>>> _pendingActionsFor(
    HalaqaEntity halaqa,
    DateTime now,
  ) async {
    final actions = <TeacherAgendaAction>[];

    // Attendance register readiness (reuse W2 read — dedupe already applied).
    final attendanceEither = await repository.getHalaqaAttendanceForDate(
      halaqaId: halaqa.id,
      date: now,
    );
    final attendanceFailure = attendanceEither.fold<Failure?>(
      (l) => l,
      (_) => null,
    );
    if (attendanceFailure != null) return Left(attendanceFailure);
    final records = attendanceEither.getOrElse((_) => const []);
    if (_attendanceIncomplete(halaqa, records)) {
      actions.add(TeacherAgendaAction.takeAttendance);
    }

    // Pending-review readiness (reuse W1 read + isPendingReview).
    final reviewsEither = await repository.getHalaqaRecitationRecords(
      halaqa.id,
    );
    final reviewsFailure = reviewsEither.fold<Failure?>((l) => l, (_) => null);
    if (reviewsFailure != null) return Left(reviewsFailure);
    final recitations = reviewsEither.getOrElse((_) => const []);
    if (recitations.any((r) => r.isPendingReview)) {
      actions.add(TeacherAgendaAction.reviewRecitations);
    }

    return Right(actions);
  }

  /// Register is "incomplete" when at least one roster student has no record
  /// today. An empty roster has nothing to mark, so it is never actionable.
  bool _attendanceIncomplete(
    HalaqaEntity halaqa,
    List<AttendanceRecordEntity> records,
  ) {
    final roster = halaqa.studentIds
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (roster.isEmpty) return false;
    final marked = records.map((r) => r.studentId).toSet();
    return !marked.containsAll(roster);
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
