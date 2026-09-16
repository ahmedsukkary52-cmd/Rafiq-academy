/**
 * WA-13 / C11.3 — Live evaluation → Academy Event → notification (pure logic).
 *
 * Identity reuses the frozen Dart contract so client and server can never
 * produce two cards for the same fact:
 *   event id        `homework_reviewed_{recitationRecordId}`
 *     (lib/shared/domain/academy_event.dart → AcademyEventIds.homeworkReviewed)
 *   notification id `{observerId}_{eventId}`
 *     (lib/features/notifications/domain/entities/notification_signal_ids.dart)
 *
 * No Firebase imports here — all Firestore/messaging I/O lives in the wrapper.
 */

/** Mirrors NotificationTypes.assignment used by the in-app composer. */
export const EVALUATION_NOTIFICATION_TYPE = "assignment";

/** Deep-link kind carried in the (small) FCM data payload. */
export const EVALUATION_NOTIFICATION_KIND = "evaluation";

/** Bounded retries for one notification delivery (idempotency guard). */
export const MAX_DELIVERY_ATTEMPTS = 3;

/** FCM data payloads carry stable ids only — never private user data. */
export const MAX_DATA_PAYLOAD_BYTES = 1024;

export type EvaluationDoc = Record<string, unknown> | undefined | null;

export type EvaluationFacts = {
  evaluationId: string;
  studentId: string;
  halaqaId: string;
  sessionId: string;
  grade: string;
};

export type EvaluationDecision =
  | { notify: false; reason: string }
  | { notify: true; eventId: string; facts: EvaluationFacts };

export function evaluationEventId(recitationRecordId: string): string {
  return `homework_reviewed_${recitationRecordId.trim()}`;
}

export function notificationIdFor(
  observerId: string,
  eventId: string,
): string {
  return `${observerId.trim()}_${eventId.trim()}`;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * A teacher live evaluation is a reviewed recitation record that is not an
 * assignment submission review (those keep their own client-published
 * `HomeworkReviewed` flow — see EvaluationPolicy.isSessionScopedTeacherEvaluation).
 */
function isLiveEvaluation(doc: Record<string, unknown>): boolean {
  if (text(doc.studentId) === "") return false;
  if (text(doc.assignmentId) !== "") return false;
  const reviewStatus = text(doc.reviewStatus);
  return reviewStatus === "" || reviewStatus === "reviewed";
}

/**
 * Notify once, on the transition into "reviewed live evaluation".
 *
 * Later edits of the same record keep the same deterministic ids, so even if a
 * retry re-evaluates this decision no second notification can be produced.
 */
export function decideEvaluationNotification(params: {
  recordId: string;
  before: EvaluationDoc;
  after: EvaluationDoc;
}): EvaluationDecision {
  const recordId = params.recordId.trim();
  if (recordId === "") return { notify: false, reason: "missing_record_id" };

  const after = params.after;
  if (!after) return { notify: false, reason: "deleted" };
  if (!isLiveEvaluation(after)) {
    return { notify: false, reason: "not_live_evaluation" };
  }

  const before = params.before;
  if (before && isLiveEvaluation(before)) {
    return { notify: false, reason: "already_notified_fact" };
  }

  return {
    notify: true,
    eventId: evaluationEventId(recordId),
    facts: {
      evaluationId: recordId,
      studentId: text(after.studentId),
      halaqaId: text(after.halaqaId),
      sessionId: text(after.sessionId),
      grade: text(after.grade),
    },
  };
}

export type ParentNotification = {
  notificationId: string;
  audience: string;
  title: string;
  body: string;
  type: string;
  /** Stable identifiers only — enough to open the persisted evaluation. */
  data: Record<string, string>;
};

/**
 * Parent-facing copy mirrors InAppAcademySignalComposer's parent wording for
 * `HomeworkReviewed`, so in-app card and push stay consistent.
 */
export function buildParentEvaluationNotification(params: {
  parentId: string;
  eventId: string;
  facts: EvaluationFacts;
  studentName?: string;
}): ParentNotification {
  const parentId = params.parentId.trim();
  const label =
    (params.studentName ?? "").trim() === ""
      ? "الطالب"
      : (params.studentName ?? "").trim();
  const grade = params.facts.grade.trim();

  const data: Record<string, string> = {
    kind: EVALUATION_NOTIFICATION_KIND,
    eventId: params.eventId,
    evaluationId: params.facts.evaluationId,
    studentId: params.facts.studentId,
  };
  if (params.facts.sessionId !== "") data.sessionId = params.facts.sessionId;
  if (params.facts.halaqaId !== "") data.halaqaId = params.facts.halaqaId;

  return {
    notificationId: notificationIdFor(parentId, params.eventId),
    audience: parentId,
    title: "تم تقييم التسميع",
    body:
      grade === ""
        ? `تم تقييم تسميع ${label}`
        : `تم تقييم تسميع ${label}: ${grade}`,
    type: EVALUATION_NOTIFICATION_TYPE,
    data,
  };
}

/** Guards payload size and blocks accidental private data in push payloads. */
export function assertSafeDataPayload(data: Record<string, string>): void {
  const forbidden = ["phone", "email", "password", "token", "address"];
  for (const key of Object.keys(data)) {
    if (forbidden.some((f) => key.toLowerCase().includes(f))) {
      throw new Error(`forbidden FCM data key: ${key}`);
    }
  }
  const size = Buffer.byteLength(JSON.stringify(data), "utf8");
  if (size > MAX_DATA_PAYLOAD_BYTES) {
    throw new Error(`FCM data payload too large: ${size} bytes`);
  }
}

export type DeliveryDoc = Record<string, unknown> | undefined | null;

export type DeliveryAttemptDecision =
  | { proceed: false; reason: string }
  | { proceed: true; attempt: number };

/**
 * Server-side idempotency for a retried Cloud Function execution.
 *
 * A delivery that already reached a terminal success state is never re-sent;
 * transient failures may be retried up to [MAX_DELIVERY_ATTEMPTS].
 */
export function decideDeliveryAttempt(
  existing: DeliveryDoc,
): DeliveryAttemptDecision {
  if (!existing) return { proceed: true, attempt: 1 };

  const status = text(existing.status);
  if (status === "sent" || status === "no_tokens") {
    return { proceed: false, reason: `already_${status}` };
  }

  const attempts =
    typeof existing.attempts === "number" && Number.isFinite(existing.attempts)
      ? existing.attempts
      : 0;

  if (attempts >= MAX_DELIVERY_ATTEMPTS) {
    return { proceed: false, reason: "max_attempts_reached" };
  }

  return { proceed: true, attempt: attempts + 1 };
}
