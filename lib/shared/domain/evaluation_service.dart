import 'package:injectable/injectable.dart';

import '../../features/schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../features/schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../features/student/domain/entities/halaqa_entity.dart';
import '../../features/student/domain/entities/recitation_record_entity.dart';
import 'evaluation_policy.dart';

/// Why [EvaluationService.openEvaluation] could not produce a ready model.
enum OpenEvaluationBlockReason {
  /// No operational teaching session for today.
  noSessionToday,

  /// Halaqa entity required to resolve today's session was missing.
  halaqaUnavailable,

  /// Record is not a session-scoped teacher evaluation (e.g. pending homework).
  notEditableSessionEvaluation,
}

/// Ready-to-present evaluation sheet state — no further business decisions needed.
///
/// Built exclusively by [EvaluationService.openEvaluation]. Screens bind fields
/// for display and submit [identity] via the upsert use case; they must not
/// re-derive session or create-vs-edit rules from this model.
class EvaluationOpenModel {
  /// Create vs edit for the sheet title and save label.
  final EvaluationSheetMode mode;

  /// Null until a student is selected (create flow with empty roster pick).
  final EvaluationIdentity? identity;

  /// Operational teaching-session id (`{halaqaId}_yyyyMMdd`).
  final String sessionId;

  /// Calendar day of [sessionId] — used as the evaluation record date.
  final DateTime sessionDate;

  final String halaqaId;

  /// When true, student and type must not change (opened from an existing card).
  final bool identityLocked;

  final String? studentId;
  final RecitationType type;
  final RecitationGrade typeGrade;
  final RecitationGrade behaviorGrade;
  final String notes;

  /// Matching stored evaluation when [mode] is edit; otherwise null.
  final RecitationRecordEntity? existing;

  const EvaluationOpenModel({
    required this.mode,
    required this.sessionId,
    required this.sessionDate,
    required this.halaqaId,
    required this.identityLocked,
    required this.type,
    required this.typeGrade,
    required this.behaviorGrade,
    required this.notes,
    this.identity,
    this.studentId,
    this.existing,
  });
}

/// Outcome of [EvaluationService.openEvaluation].
class OpenEvaluationResult {
  /// Present when opening succeeded; null when [blockReason] is set.
  final EvaluationOpenModel? model;

  /// Present when opening was refused; null when [model] is set.
  final OpenEvaluationBlockReason? blockReason;

  const OpenEvaluationResult.ready(this.model) : blockReason = null;

  const OpenEvaluationResult.blocked(this.blockReason) : model = null;

  /// Whether [model] is available for presentation.
  bool get isReady => model != null;
}

/// Application facade for teacher live evaluations.
///
/// **Screens** should call only [openEvaluation] / [canOpenSessionEvaluation]
/// and treat the result as presentation input — no session or uniqueness logic
/// in UI pages.
///
/// **Use cases** that persist call [planUpsert] so write identity and legacy
/// retirement stay aligned with [EvaluationPolicy].
///
/// Rules live in [EvaluationPolicy]; change product defaults there first.
@lazySingleton
class EvaluationService {
  static const _sessionsMapper = HalaqaWeeklySessionsMapper();

  static const _defaultGrade = RecitationGrade.good;

  const EvaluationService();

  /// Opens a teacher evaluation sheet as a ready [EvaluationOpenModel].
  ///
  /// Internally resolves today's operational session (unless [sessionId] /
  /// [sessionDate] or [existingRecord] already supply context), builds the
  /// evaluation identity, and decides create vs edit against [records].
  ///
  /// **Typical screen call (Evaluate / +):**
  /// ```dart
  /// openEvaluation(
  ///   halaqaId: halaqaId,
  ///   halaqa: halaqa,
  ///   records: loadedEvaluations,
  ///   studentId: optionalPreselect,
  /// );
  /// ```
  ///
  /// **Open existing card:** pass [existingRecord] (locks identity).
  ///
  /// **Re-resolve inside an open sheet** (student/type change): pass the
  /// current [sessionId], [sessionDate], and [identityLocked] so today's
  /// session is not re-derived.
  ///
  /// Returns [OpenEvaluationResult.blocked] when there is no session today,
  /// [halaqa] is required but missing, or [existingRecord] is not editable.
  OpenEvaluationResult openEvaluation({
    required String halaqaId,
    required Iterable<RecitationRecordEntity> records,
    HalaqaEntity? halaqa,
    String? studentId,
    RecitationType type = RecitationType.memorization,
    RecitationRecordEntity? existingRecord,
    String? sessionId,
    DateTime? sessionDate,
    bool identityLocked = false,
    DateTime? now,
  }) {
    if (existingRecord != null) {
      return _openFromExistingRecord(
        records: records,
        existingRecord: existingRecord,
      );
    }

    final resolved = _resolveSessionContext(
      halaqa: halaqa,
      sessionId: sessionId,
      sessionDate: sessionDate,
      now: now,
    );
    if (resolved.blockReason != null) {
      return OpenEvaluationResult.blocked(resolved.blockReason!);
    }

    final sid = resolved.sessionId!;
    final sday = resolved.sessionDate!;
    final trimmedStudent = studentId?.trim();
    if (trimmedStudent == null || trimmedStudent.isEmpty) {
      return OpenEvaluationResult.ready(
        EvaluationOpenModel(
          mode: EvaluationSheetMode.create,
          identity: null,
          sessionId: sid,
          sessionDate: sday,
          halaqaId: halaqaId.trim(),
          identityLocked: false,
          studentId: null,
          type: type,
          typeGrade: _defaultGrade,
          behaviorGrade: _defaultGrade,
          notes: '',
          existing: null,
        ),
      );
    }

    final identity = EvaluationIdentity(
      sessionId: sid,
      halaqaId: halaqaId.trim(),
      studentId: trimmedStudent,
      type: type,
    );
    final decision = EvaluationPolicy.resolveOpen(
      identity: identity,
      records: records,
    );
    return OpenEvaluationResult.ready(
      _modelFromDecision(
        decision: decision,
        identity: identity,
        sessionId: sid,
        sessionDate: sday,
        identityLocked: identityLocked,
        type: type,
      ),
    );
  }

  /// Whether a timeline card may open the teacher live-evaluation sheet.
  ///
  /// Pending homework submissions and other non-session-scoped rows return
  /// false (they keep the separate pending-review flow).
  bool canOpenSessionEvaluation(RecitationRecordEntity record) =>
      EvaluationPolicy.identityOf(record) != null;

  /// Write plan for upserting a teacher live evaluation without duplicates.
  ///
  /// Always targets the deterministic document id; [EvaluationUpsertPlan.retireDocumentIds]
  /// lists legacy colliding docs to delete in the same batch.
  EvaluationUpsertPlan planUpsert({
    required EvaluationIdentity identity,
    required Iterable<RecitationRecordEntity> records,
  }) =>
      EvaluationPolicy.planUpsert(identity: identity, records: records);

  OpenEvaluationResult _openFromExistingRecord({
    required Iterable<RecitationRecordEntity> records,
    required RecitationRecordEntity existingRecord,
  }) {
    final identity = EvaluationPolicy.identityOf(existingRecord);
    if (identity == null) {
      return const OpenEvaluationResult.blocked(
        OpenEvaluationBlockReason.notEditableSessionEvaluation,
      );
    }

    final decision = EvaluationPolicy.resolveOpen(
      identity: identity,
      records: records,
    );
    final existing = decision.existing ?? existingRecord;
    final sessionDate = DateTime(
      existing.date.year,
      existing.date.month,
      existing.date.day,
    );

    return OpenEvaluationResult.ready(
      _modelFromDecision(
        decision: EvaluationOpenDecision.edit(existing),
        identity: identity,
        sessionId: identity.sessionId,
        sessionDate: sessionDate,
        identityLocked: true,
        type: identity.type,
      ),
    );
  }

  ({
    String? sessionId,
    DateTime? sessionDate,
    OpenEvaluationBlockReason? blockReason,
  }) _resolveSessionContext({
    required HalaqaEntity? halaqa,
    required String? sessionId,
    required DateTime? sessionDate,
    required DateTime? now,
  }) {
    final providedId = sessionId?.trim() ?? '';
    if (providedId.isNotEmpty && sessionDate != null) {
      return (
        sessionId: providedId,
        sessionDate: DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
        ),
        blockReason: null,
      );
    }

    if (halaqa == null) {
      return (
        sessionId: null,
        sessionDate: null,
        blockReason: OpenEvaluationBlockReason.halaqaUnavailable,
      );
    }

    final sid = _resolveTodaySessionId(halaqa, now: now);
    final sday = _resolveTodaySessionDay(halaqa, now: now);
    if (sid == null || sday == null) {
      return (
        sessionId: null,
        sessionDate: null,
        blockReason: OpenEvaluationBlockReason.noSessionToday,
      );
    }
    return (sessionId: sid, sessionDate: sday, blockReason: null);
  }

  String? _resolveTodaySessionId(HalaqaEntity halaqa, {DateTime? now}) {
    final days = _sessionsMapper.mapTodayOperationalDays(
      [halaqaScheduleSourceFromEntity(halaqa)],
      now: now,
    );
    if (days.isEmpty) return null;
    return days.first.session.id;
  }

  DateTime? _resolveTodaySessionDay(HalaqaEntity halaqa, {DateTime? now}) {
    final days = _sessionsMapper.mapTodayOperationalDays(
      [halaqaScheduleSourceFromEntity(halaqa)],
      now: now,
    );
    if (days.isEmpty) return null;
    final start = days.first.session.startAt;
    return DateTime(start.year, start.month, start.day);
  }

  EvaluationOpenModel _modelFromDecision({
    required EvaluationOpenDecision decision,
    required EvaluationIdentity identity,
    required String sessionId,
    required DateTime sessionDate,
    required bool identityLocked,
    required RecitationType type,
  }) {
    final existing = decision.existing;
    return EvaluationOpenModel(
      mode: decision.mode,
      identity: identity,
      sessionId: sessionId,
      sessionDate: sessionDate,
      halaqaId: identity.halaqaId,
      identityLocked: identityLocked,
      studentId: identity.studentId,
      type: type,
      typeGrade: existing?.grade ?? _defaultGrade,
      behaviorGrade: existing?.behaviorGrade ?? _defaultGrade,
      notes: existing?.notes?.trim() ?? '',
      existing: existing,
    );
  }
}
