import 'package:injectable/injectable.dart';

import '../../features/schedule/domain/entities/class_session_entity.dart';
import '../../features/schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../features/schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../features/student/domain/entities/halaqa_entity.dart';
import '../../features/teacher/domain/entities/attendance_record_entity.dart';
import '../../features/teacher/domain/repositories/teacher_repository.dart';
import '../utils/attendance_policy.dart';

/// Create vs edit for the attendance register sheet.
enum AttendanceRegisterMode { create, edit }

/// Why [AttendanceService.planSessionSave] refused a write.
enum AttendanceSaveBlockReason {
  /// Operational session end has passed — register is read-only.
  sessionClosed,

  /// Not every roster student has a mark.
  registerIncomplete,

  /// No draft marks to persist.
  nothingToSave,

  /// Session identity missing — every new attendance row requires sessionId.
  missingSessionId,
}

/// Ready-to-present attendance register — built only by [AttendanceService].
class AttendanceOpenModel {
  final AttendanceRegisterMode mode;

  /// Operational teaching-session id (`{halaqaId}_yyyyMMdd`).
  final String sessionId;

  /// Calendar day of [sessionId].
  final DateTime sessionDate;

  final String halaqaId;

  /// Schedule-derived session end when known; null → day-end close rule.
  final DateTime? sessionEndAt;

  /// False when the operational session is closed (view-only).
  final bool canEdit;

  /// Existing status by student id for this [sessionId] (preferred doc wins).
  final Map<String, AttendanceStatus> existingByStudentId;

  const AttendanceOpenModel({
    required this.mode,
    required this.sessionId,
    required this.sessionDate,
    required this.halaqaId,
    required this.canEdit,
    required this.existingByStudentId,
    this.sessionEndAt,
  });
}

/// Draft mark used by [AttendanceService.planSessionSave].
class AttendanceDraftMark {
  final String studentId;
  final String studentName;
  final AttendanceStatus status;

  const AttendanceDraftMark({
    required this.studentId,
    required this.studentName,
    required this.status,
  });
}

/// Write plan: deterministic session ids, no duplicates.
class AttendanceSessionSavePlan {
  final String sessionId;
  final DateTime sessionDate;
  final List<AttendanceRecordEntity> records;

  /// Legacy / colliding docs to delete in the same batch as the upsert.
  final List<String> retireDocumentIds;

  const AttendanceSessionSavePlan({
    required this.sessionId,
    required this.sessionDate,
    required this.records,
    this.retireDocumentIds = const [],
  });
}

/// Outcome of [AttendanceService.planSessionSave].
class AttendanceSaveResult {
  final AttendanceSessionSavePlan? plan;
  final AttendanceSaveBlockReason? blockReason;

  const AttendanceSaveResult.ready(this.plan) : blockReason = null;

  const AttendanceSaveResult.blocked(this.blockReason) : plan = null;

  bool get isReady => plan != null;
}

/// Application facade for teacher session attendance (EvaluationService parity).
///
/// **Screens** call only [openRegister] / [planSessionSave] /
/// [isRegisterComplete] and treat results as presentation input — no session,
/// uniqueness, or closed-session logic in UI or TeacherBloc.
///
/// **Persistence** stays on [SaveDayAttendanceUseCase] / TeacherBloc; this
/// service never queries Firestore.
///
/// ## Business rules (SSOT)
///
/// **Identity** — One mark per student per operational session.
/// Document id: `{sessionId}_{studentId}` (same shape family as evaluations).
/// [sessionId] is `{halaqaId}_yyyyMMdd` and is **mandatory** on every write.
/// Legacy W2 ids `{halaqaId}_{studentId}_{yyyyMMdd}` are retired on save.
///
/// **Session** — Prefer today's schedule-derived operational day when [halaqa]
/// is provided; otherwise the selected/calendar day. Matching stored rows uses
/// `sessionId` first, with date-derived fallback for legacy docs.
///
/// **Edit** — Re-saving the same session **updates** the deterministic doc
/// (merge upsert); it never creates a second mark for that student+session.
///
/// **Closed session** — Editable while `now < sessionEndAt` when the schedule
/// provides an end time; otherwise until the end of the session calendar day.
/// After close (including historical days), the register is read-only.
///
/// **Statuses** — `present` / `late` = attended; `absent` = absence (at-risk);
/// `excused` = first-class status, neither attended nor absent, excluded from
/// attendance-percent denominator. Analytics / at-risk re-read
/// `attendanceRecords` after save — no separate sync writes.
@lazySingleton
class AttendanceService {
  static const _sessionsMapper = HalaqaWeeklySessionsMapper();

  const AttendanceService();

  /// Opens the register for an operational session (create vs edit + canEdit).
  AttendanceOpenModel openRegister({
    required String halaqaId,
    required Iterable<AttendanceRecordEntity> existingRecords,
    HalaqaEntity? halaqa,
    DateTime? sessionDate,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final bounds = _resolveSessionBounds(
      halaqaId: halaqaId,
      halaqa: halaqa,
      sessionDate: sessionDate,
      now: clock,
    );

    final byStudent = <String, AttendanceStatus>{};
    for (final record in existingRecords) {
      if (!AttendancePolicy.belongsToSession(
        recordSessionId: record.sessionId,
        recordHalaqaId: record.halaqaId,
        recordDate: record.date,
        sessionId: bounds.sessionId,
        halaqaId: halaqaId,
      )) {
        continue;
      }
      final preferredId = AttendancePolicy.documentId(
        sessionId: bounds.sessionId,
        studentId: record.studentId,
      );
      final existing = byStudent[record.studentId];
      if (existing == null || record.id == preferredId) {
        byStudent[record.studentId] = record.status;
      }
    }

    final mode = byStudent.isEmpty
        ? AttendanceRegisterMode.create
        : AttendanceRegisterMode.edit;

    return AttendanceOpenModel(
      mode: mode,
      sessionId: bounds.sessionId,
      sessionDate: bounds.sessionDate,
      sessionEndAt: bounds.sessionEndAt,
      halaqaId: halaqaId.trim(),
      canEdit: AttendancePolicy.canEditSession(
        sessionDate: bounds.sessionDate,
        sessionEndAt: bounds.sessionEndAt,
        now: clock,
      ),
      existingByStudentId: Map.unmodifiable(byStudent),
    );
  }

  /// Whether every roster student has a draft mark (save gate).
  bool isRegisterComplete({
    required Iterable<String> rosterStudentIds,
    required Iterable<String> markedStudentIds,
  }) => AttendancePolicy.isRegisterComplete(
    rosterStudentIds: rosterStudentIds,
    markedStudentIds: markedStudentIds,
  );

  /// Builds an upsert plan for one student per operational session.
  ///
  /// Always targets [AttendancePolicy.documentId]. Refuses writes when the
  /// session is closed, [sessionId] is missing, or the register is incomplete.
  /// [AttendanceSessionSavePlan.retireDocumentIds] lists legacy/colliding docs.
  AttendanceSaveResult planSessionSave({
    required AttendanceOpenModel open,
    required String recordedBy,
    required Iterable<String> rosterStudentIds,
    required Iterable<AttendanceDraftMark> marks,
    Iterable<AttendanceRecordEntity> existingRecords = const [],
    DateTime? now,
  }) {
    final sessionId = open.sessionId.trim();
    if (sessionId.isEmpty) {
      return const AttendanceSaveResult.blocked(
        AttendanceSaveBlockReason.missingSessionId,
      );
    }

    if (!AttendancePolicy.canEditSession(
      sessionDate: open.sessionDate,
      sessionEndAt: open.sessionEndAt,
      now: now,
    )) {
      return const AttendanceSaveResult.blocked(
        AttendanceSaveBlockReason.sessionClosed,
      );
    }

    final trimmedMarks = marks
        .where((m) => m.studentId.trim().isNotEmpty)
        .toList(growable: false);
    if (trimmedMarks.isEmpty) {
      return const AttendanceSaveResult.blocked(
        AttendanceSaveBlockReason.nothingToSave,
      );
    }

    if (!isRegisterComplete(
      rosterStudentIds: rosterStudentIds,
      markedStudentIds: trimmedMarks.map((m) => m.studentId),
    )) {
      return const AttendanceSaveResult.blocked(
        AttendanceSaveBlockReason.registerIncomplete,
      );
    }

    final records = <AttendanceRecordEntity>[];
    final retire = <String>{};

    for (final mark in trimmedMarks) {
      final studentId = mark.studentId.trim();
      final id = AttendancePolicy.documentId(
        sessionId: sessionId,
        studentId: studentId,
      );
      records.add(
        AttendanceRecordEntity(
          id: id,
          studentId: studentId,
          studentName: mark.studentName.trim(),
          halaqaId: open.halaqaId,
          date: open.sessionDate,
          status: mark.status,
          recordedBy: recordedBy.trim(),
          sessionId: sessionId,
        ),
      );

      // Retire legacy W2 D8 id + any other colliding session docs.
      final legacyId = AttendancePolicy.legacyDocumentId(
        halaqaId: open.halaqaId,
        studentId: studentId,
        date: open.sessionDate,
      );
      if (legacyId != id) retire.add(legacyId);

      for (final existing in existingRecords) {
        if (!AttendancePolicy.belongsToSession(
          recordSessionId: existing.sessionId,
          recordHalaqaId: existing.halaqaId,
          recordDate: existing.date,
          sessionId: sessionId,
          halaqaId: open.halaqaId,
        )) {
          continue;
        }
        if (existing.studentId.trim() != studentId) continue;
        final existingId = existing.id.trim();
        if (existingId.isNotEmpty && existingId != id) {
          retire.add(existingId);
        }
      }
    }

    return AttendanceSaveResult.ready(
      AttendanceSessionSavePlan(
        sessionId: sessionId,
        sessionDate: open.sessionDate,
        records: records,
        retireDocumentIds: retire.toList(growable: false),
      ),
    );
  }

  ({
    String sessionId,
    DateTime sessionDate,
    DateTime? sessionEndAt,
  }) _resolveSessionBounds({
    required String halaqaId,
    required HalaqaEntity? halaqa,
    required DateTime? sessionDate,
    required DateTime now,
  }) {
    final today = AttendancePolicy.dayStart(now);

    if (sessionDate == null && halaqa != null) {
      final days = _sessionsMapper.mapTodayOperationalDays(
        [halaqaScheduleSourceFromEntity(halaqa)],
        now: now,
      );
      if (days.isNotEmpty) {
        final session = days.first.session;
        final day = AttendancePolicy.dayStart(session.startAt);
        return (
          sessionId: AttendancePolicy.sessionIdForDay(
            halaqaId: halaqaId,
            day: day,
          ),
          sessionDate: day,
          sessionEndAt: session.endAt,
        );
      }
    }

    final day = AttendancePolicy.dayStart(sessionDate ?? now);
    final sid = AttendancePolicy.sessionIdForDay(halaqaId: halaqaId, day: day);
    final endAt = _endAtForDay(halaqa: halaqa, day: day, now: now);

    if (halaqa != null && day == today) {
      final days = _sessionsMapper.mapTodayOperationalDays(
        [halaqaScheduleSourceFromEntity(halaqa)],
        now: now,
      );
      if (days.isNotEmpty) {
        return (
          sessionId: sid,
          sessionDate: day,
          sessionEndAt: days.first.session.endAt,
        );
      }
    }

    return (sessionId: sid, sessionDate: day, sessionEndAt: endAt);
  }

  DateTime? _endAtForDay({
    required HalaqaEntity? halaqa,
    required DateTime day,
    required DateTime now,
  }) {
    if (halaqa == null) return null;
    final source = halaqaScheduleSourceFromEntity(halaqa);
    ClassSessionEntity? best;
    for (final session in _sessionsMapper.map(source, now: day)) {
      if (!AttendancePolicy.isSameCalendarDay(session.startAt, day)) continue;
      if (best == null || session.endAt.isAfter(best.endAt)) {
        best = session;
      }
    }
    return best?.endAt;
  }
}
