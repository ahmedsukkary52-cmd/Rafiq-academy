import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/halaqa_day_readiness.dart';
import '../../../../shared/domain/load_halaqa_day_readiness.dart';
import '../../../awards/domain/entities/award_entities.dart';
import '../../../awards/domain/repositories/awards_repository.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
import '../../../schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../../schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../read_models/teacher_day_agenda.dart';
import '../read_models/teacher_home_feed.dart';
import '../read_models/teacher_recent_activity.dart';
import '../repositories/teacher_repository.dart';
import 'get_today_agenda_usecase.dart';

/// Derives Teacher Home feed in **one** pass:
/// - W3 today agenda (same rules as [GetTodayAgendaUseCase])
/// - recent activities from the same attendance/recitation reads + awards
///
/// Avoids a second Firestore round-trip for today's operational halaqat.
@lazySingleton
class GetTeacherHomeFeedUseCase
    extends UseCase<TeacherHomeFeed, TodayAgendaParams> {
  final TeacherRepository teacherRepository;
  final AwardsRepository awardsRepository;
  final HalaqaWeeklySessionsMapper _sessionsMapper;

  static const int _activityLimit = 5;
  static const int _perHalaqaReviewedCap = 3;
  static const int _perHalaqaAwardsCap = 3;

  GetTeacherHomeFeedUseCase({
    required this.teacherRepository,
    required this.awardsRepository,
  }) : _sessionsMapper = const HalaqaWeeklySessionsMapper();

  @override
  Future<Either<Failure, TeacherHomeFeed>> call(
    TodayAgendaParams params,
  ) async {
    final now = params.now ?? DateTime.now();
    final byId = {for (final h in params.halaqat) h.id: h};

    final days = _sessionsMapper.mapTodayOperationalDays(
      params.halaqat.map(halaqaScheduleSourceFromEntity),
      now: now,
    );
    final todayIds = days.map((d) => d.halaqaId).toSet();

    final agendaItems = <TeacherAgendaItem>[];
    final activities = <TeacherRecentActivity>[];

    for (final day in days) {
      final halaqa = byId[day.halaqaId];
      if (halaqa == null) continue;

      final factsEither = await loadHalaqaDayFacts(
        teacherRepository: teacherRepository,
        halaqa: halaqa,
        now: now,
      );
      final failure = factsEither.fold<Failure?>((l) => l, (_) => null);
      if (failure != null) return Left(failure);

      final facts = factsEither.getOrElse(
        (_) => throw StateError('facts missing'),
      );

      _appendAttendanceActivity(
        activities,
        halaqa: halaqa,
        attendanceDates: facts.attendance.map((r) => r.date),
      );
      _appendEvaluationActivities(
        activities,
        halaqa: halaqa,
        recitations: facts.recitations,
      );

      if (!facts.readiness.isComplete) {
        agendaItems.add(
          TeacherAgendaItem(
            halaqaId: halaqa.id,
            halaqaName: halaqa.name,
            startAt: day.session.startAt,
            pendingActions: facts.readiness.gaps.map(_actionFor).toList(),
          ),
        );
      }
    }

    // Non-today halaqat: recitations for recent evaluations (not loaded above).
    for (final halaqa in params.halaqat) {
      if (todayIds.contains(halaqa.id)) continue;

      final reviewsEither = await teacherRepository.getHalaqaRecitationRecords(
        halaqa.id,
      );
      reviewsEither.fold(
        (_) {},
        (recs) => _appendEvaluationActivities(
          activities,
          halaqa: halaqa,
          recitations: recs,
        ),
      );
    }

    // Awards for every halaqa (not part of W3 readiness I/O).
    for (final halaqa in params.halaqat) {
      final awardsEither = await awardsRepository.getGrantedAwards(halaqa.id);
      awardsEither.fold(
        (_) {},
        (awards) => _appendAwardActivities(
          activities,
          halaqa: halaqa,
          awards: awards,
        ),
      );
    }

    activities.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final limited = <TeacherRecentActivity>[];
    final seen = <String>{};
    for (final item in activities) {
      if (!seen.add(item.id)) continue;
      limited.add(item);
      if (limited.length >= _activityLimit) break;
    }

    return Right(
      TeacherHomeFeed(
        agenda: TeacherDayAgenda(
          items: agendaItems,
          sessionsTodayCount: days.length,
          featuredSession: _featuredSession(days, byId),
        ),
        recentActivities: limited,
      ),
    );
  }

  void _appendAttendanceActivity(
    List<TeacherRecentActivity> out, {
    required HalaqaEntity halaqa,
    required Iterable<DateTime> attendanceDates,
  }) {
    final dates = attendanceDates.toList();
    if (dates.isEmpty) return;
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    out.add(
      TeacherRecentActivity(
        id: 'attendance_${halaqa.id}_${latest.toIso8601String()}',
        kind: TeacherRecentActivityKind.attendance,
        title: 'تسجيل حضور',
        subtitle: halaqa.name,
        occurredAt: latest,
        halaqaId: halaqa.id,
      ),
    );
  }

  void _appendEvaluationActivities(
    List<TeacherRecentActivity> out, {
    required HalaqaEntity halaqa,
    required List<RecitationRecordEntity> recitations,
  }) {
    final reviewed = recitations
        .where((r) => !r.isPendingReview && r.grade != null)
        .toList();
    reviewed.sort((a, b) {
      final aAt = a.submittedAt ?? a.date;
      final bAt = b.submittedAt ?? b.date;
      return bAt.compareTo(aAt);
    });

    for (final record in reviewed.take(_perHalaqaReviewedCap)) {
      final at = record.submittedAt ?? record.date;
      out.add(
        TeacherRecentActivity(
          id: 'eval_${record.id}',
          kind: TeacherRecentActivityKind.evaluation,
          title: 'تقييم ${record.studentName}',
          subtitle: record.grade!.label,
          occurredAt: at,
          halaqaId: halaqa.id,
        ),
      );
    }
  }

  void _appendAwardActivities(
    List<TeacherRecentActivity> out, {
    required HalaqaEntity halaqa,
    required List<GrantedAwardEntity> awards,
  }) {
    final sorted = [...awards]
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    for (final award in sorted.take(_perHalaqaAwardsCap)) {
      out.add(
        TeacherRecentActivity(
          id: 'award_${award.id}',
          kind: TeacherRecentActivityKind.award,
          title: 'منح شارة "${award.type.title}"',
          subtitle: award.recipientCount > 1
              ? '${award.recipientCount} طلاب'
              : award.studentName,
          occurredAt: award.grantedAt,
          halaqaId: halaqa.id,
        ),
      );
    }
  }

  TeacherTodaySession? _featuredSession(
    List<TodayOperationalDay> days,
    Map<String, HalaqaEntity> byId,
  ) {
    if (days.isEmpty) return null;

    final TodayOperationalDay day;
    final live = days.where((d) => d.session.status == ClassSessionStatus.live);
    if (live.isNotEmpty) {
      day = live.first;
    } else {
      final upcoming = days.where(
        (d) => d.session.status == ClassSessionStatus.upcoming,
      );
      day = upcoming.isNotEmpty ? upcoming.first : days.first;
    }

    final halaqa = byId[day.halaqaId];
    return TeacherTodaySession(
      halaqaId: day.halaqaId,
      halaqaName: halaqa?.name ?? day.session.title,
      startAt: day.session.startAt,
      studentCount: halaqa?.studentIds.length ?? 0,
    );
  }

  TeacherAgendaAction _actionFor(HalaqaDayGap gap) => switch (gap.kind) {
    HalaqaDayGapKind.attendanceIncomplete => TeacherAgendaAction.takeAttendance,
    HalaqaDayGapKind.homeworkPending => TeacherAgendaAction.sendHomework,
    HalaqaDayGapKind.reviewsPending => TeacherAgendaAction.reviewRecitations,
  };
}
