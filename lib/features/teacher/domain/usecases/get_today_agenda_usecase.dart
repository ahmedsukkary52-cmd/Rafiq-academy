import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../schedule/data/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../schedule/data/models/halaqa_schedule_source_model.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
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
///   halaqat in D6/D7 order (day boundaries via [AttendancePolicy]),
/// - asks [AttendancePolicy.isRegisterIncomplete] for register readiness,
/// - asks [RecitationRecordEntity.isPendingReview] for review readiness,
/// - asks the repository for the halaqa's latest assignment `dueDate` (W1 D7)
///   and compares its calendar day via [AttendancePolicy.dayStart].
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
      params.halaqat.map(_sourceOf),
      now: now,
    );

    // 2. Readiness per halaqa; keep only halaqat with remaining work.
    final items = <TeacherAgendaItem>[];
    for (final day in days) {
      final halaqaId = _halaqaIdOf(day);
      final halaqa = byId[halaqaId];
      if (halaqa == null) continue;

      final actionsEither = await _pendingActionsFor(halaqa, now);
      final failure = actionsEither.fold<Failure?>((l) => l, (_) => null);
      if (failure != null) return Left(failure);

      final actions = actionsEither.getOrElse((_) => const []);
      if (actions.isEmpty) continue;

      items.add(
        TeacherAgendaItem(
          halaqaId: halaqa.id,
          halaqaName: halaqa.name,
          startAt: day.startAt,
          pendingActions: actions,
        ),
      );
    }

    return Right(
      TeacherDayAgenda(items: items, sessionsTodayCount: days.length),
    );
  }

  Future<Either<Failure, List<TeacherAgendaAction>>> _pendingActionsFor(
    HalaqaEntity halaqa,
    DateTime now,
  ) async {
    final actions = <TeacherAgendaAction>[];

    // Register readiness — comparison owned by AttendancePolicy (W2).
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
    if (AttendancePolicy.isRegisterIncomplete(
      rosterStudentIds: halaqa.studentIds,
      markedStudentIds: records.map((r) => r.studentId),
    )) {
      actions.add(TeacherAgendaAction.takeAttendance);
    }

    // Homework-assigned readiness — W1 D7 at halaqa scope (latest dueDate).
    final dueEither = await repository.getLatestAssignmentDueDate(halaqa.id);
    final dueFailure = dueEither.fold<Failure?>((l) => l, (_) => null);
    if (dueFailure != null) return Left(dueFailure);
    final latestDue = dueEither.getOrElse((_) => null);
    if (!_isLatestDueToday(latestDue, now)) {
      actions.add(TeacherAgendaAction.sendHomework);
    }

    // Pending-review readiness — visibility owned by RecitationRecordEntity.
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

  /// W1 D7 "current" assignment is the latest `dueDate`. It counts as
  /// "today's" when that dueDate's calendar day matches [now] (W2 day SSOT).
  bool _isLatestDueToday(DateTime? latestDue, DateTime now) {
    if (latestDue == null) return false;
    return AttendancePolicy.dayStart(latestDue) ==
        AttendancePolicy.dayStart(now);
  }

  /// Operational-day ids are `${halaqaId}_yyyyMMdd` (Pre-Slice).
  String _halaqaIdOf(ClassSessionEntity day) {
    final i = day.id.lastIndexOf('_');
    if (i <= 0) return day.id;
    return day.id.substring(0, i);
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
