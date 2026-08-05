import '../../features/student/domain/entities/recitation_record_entity.dart';

/// Business identity of a teacher live evaluation (session-scoped SSOT).
///
/// Uniqueness: [sessionId] + [halaqaId] + [studentId] + [type].
/// Never encode identity from a calendar date alone when a session exists.
class EvaluationIdentity {
  final String sessionId;
  final String halaqaId;
  final String studentId;
  final RecitationType type;

  const EvaluationIdentity({
    required this.sessionId,
    required this.halaqaId,
    required this.studentId,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationIdentity &&
          sessionId == other.sessionId &&
          halaqaId == other.halaqaId &&
          studentId == other.studentId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(sessionId, halaqaId, studentId, type);
}

enum EvaluationSheetMode { create, edit }

/// Pure create-vs-edit decision for Evaluate / sheet open.
class EvaluationOpenDecision {
  final EvaluationSheetMode mode;
  final RecitationRecordEntity? existing;

  const EvaluationOpenDecision.create()
      : mode = EvaluationSheetMode.create,
        existing = null;

  const EvaluationOpenDecision.edit(this.existing)
      : mode = EvaluationSheetMode.edit;
}

/// Where to write so duplicates are structurally impossible.
class EvaluationUpsertPlan {
  /// Deterministic Firestore document id (always preferred).
  final String documentId;

  final EvaluationSheetMode mode;
  final RecitationRecordEntity? existing;

  /// Legacy / colliding docs to delete after upserting [documentId].
  final List<String> retireDocumentIds;

  const EvaluationUpsertPlan({
    required this.documentId,
    required this.mode,
    required this.existing,
    required this.retireDocumentIds,
  });
}

/// Single owner of evaluation identity, uniqueness, and create-vs-edit.
///
/// UI pages and Firestore repositories must not re-encode these rules.
/// Change product rules here only.
class EvaluationPolicy {
  const EvaluationPolicy._();

  /// Operational teaching-day session id — same shape as
  /// [HalaqaWeeklySessionsMapper] `_asOperationalDay`: `{halaqaId}_yyyyMMdd`.
  static String sessionIdForDay({
    required String halaqaId,
    required DateTime day,
  }) {
    final d = DateTime(day.year, day.month, day.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dayNum = d.day.toString().padLeft(2, '0');
    return '${halaqaId.trim()}_$y$m$dayNum';
  }

  static String typeKey(RecitationType type) =>
      type == RecitationType.memorization ? 'memorization' : 'review';

  /// Deterministic document id — uniqueness enforcement at write time.
  /// Format: `{sessionId}_{studentId}_{memorization|review}`
  static String documentId(EvaluationIdentity identity) {
    final sessionId = identity.sessionId.trim();
    final studentId = identity.studentId.trim();
    return '${sessionId}_${studentId}_${typeKey(identity.type)}';
  }

  /// Whether [record] participates in session-scoped teacher uniqueness.
  ///
  /// Pending homework submissions (assignment-linked) are out of scope —
  /// they keep their own review flow and must not collide with live evals.
  static bool isSessionScopedTeacherEvaluation(RecitationRecordEntity record) {
    if (record.isPendingReview) return false;
    final assignmentId = record.assignmentId?.trim() ?? '';
    if (assignmentId.isNotEmpty) return false;
    return true;
  }

  /// Derive identity from a stored record when possible.
  ///
  /// Prefers [RecitationRecordEntity.sessionId]; for legacy teacher live
  /// evals without it, reconstructs the operational session id from [date].
  static EvaluationIdentity? identityOf(RecitationRecordEntity record) {
    if (!isSessionScopedTeacherEvaluation(record)) return null;

    final halaqaId = record.halaqaId.trim();
    final studentId = record.studentId.trim();
    if (halaqaId.isEmpty || studentId.isEmpty) return null;

    final stored = record.sessionId?.trim() ?? '';
    final sessionId = stored.isNotEmpty
        ? stored
        : sessionIdForDay(halaqaId: halaqaId, day: record.date);

    return EvaluationIdentity(
      sessionId: sessionId,
      halaqaId: halaqaId,
      studentId: studentId,
      type: record.type,
    );
  }

  static bool matchesIdentity(
    RecitationRecordEntity record,
    EvaluationIdentity identity,
  ) {
    if (!isSessionScopedTeacherEvaluation(record)) return false;

    final preferredId = documentId(identity);
    if (record.id == preferredId) return true;

    if (record.halaqaId.trim() != identity.halaqaId.trim()) return false;
    if (record.studentId.trim() != identity.studentId.trim()) return false;
    if (record.type != identity.type) return false;

    final stored = record.sessionId?.trim() ?? '';
    if (stored.isNotEmpty) {
      return stored == identity.sessionId.trim();
    }

    // Legacy (no sessionId): same operational day as the identity session.
    final derived = sessionIdForDay(
      halaqaId: record.halaqaId,
      day: record.date,
    );
    return derived == identity.sessionId.trim();
  }

  /// First matching evaluation for [identity], or null.
  static RecitationRecordEntity? findExisting({
    required EvaluationIdentity identity,
    required Iterable<RecitationRecordEntity> records,
  }) {
    final preferredId = documentId(identity);
    RecitationRecordEntity? byPreferred;
    RecitationRecordEntity? byFields;

    for (final record in records) {
      if (!matchesIdentity(record, identity)) continue;
      if (record.id == preferredId) {
        byPreferred = record;
        break;
      }
      byFields ??= record;
    }

    return byPreferred ?? byFields;
  }

  /// Create vs edit for Evaluate / sheet open — never blind-create.
  static EvaluationOpenDecision resolveOpen({
    required EvaluationIdentity identity,
    required Iterable<RecitationRecordEntity> records,
  }) {
    final existing = findExisting(identity: identity, records: records);
    if (existing == null) return const EvaluationOpenDecision.create();
    return EvaluationOpenDecision.edit(existing);
  }

  /// Write plan: always upsert [documentId]; retire colliding legacy docs.
  static EvaluationUpsertPlan planUpsert({
    required EvaluationIdentity identity,
    required Iterable<RecitationRecordEntity> records,
  }) {
    final preferredId = documentId(identity);
    final matches = records
        .where((r) => matchesIdentity(r, identity))
        .toList(growable: false);

    final existing = findExisting(identity: identity, records: matches);
    final retire = matches
        .map((r) => r.id)
        .where((id) => id.isNotEmpty && id != preferredId)
        .toSet()
        .toList(growable: false);

    return EvaluationUpsertPlan(
      documentId: preferredId,
      mode: existing == null
          ? EvaluationSheetMode.create
          : EvaluationSheetMode.edit,
      existing: existing,
      retireDocumentIds: retire,
    );
  }
}
