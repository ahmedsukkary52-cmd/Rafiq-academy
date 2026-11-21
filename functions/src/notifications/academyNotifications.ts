/**
 * PH-02 / C11 — server-owned academy notification builders (pure logic).
 *
 * Recipients are resolved by Cloud Functions from relationships only
 * (halaqat.studentIds roster + parentProfiles.childrenIds); the client never
 * addresses a notification to another user.
 *
 * Identity and copy mirror the frozen Dart contracts so historical cards and
 * new cards share one id space:
 *   event ids        lib/shared/domain/academy_event.dart (AcademyEventIds)
 *   notification id  `{observerId}_{eventId}` (NotificationSignalIds)
 *   copy             lib/features/notifications/domain/services/
 *                    in_app_academy_signal_composer.dart
 *
 * `data` carries stable ids only — never phone, payment or private Quran data.
 */

export const NOTIFICATION_TYPE_ATTENDANCE = "attendance";
export const NOTIFICATION_TYPE_ASSIGNMENT = "assignment";

export const ATTENDANCE_STATUSES = ["present", "absent", "late", "excused"] as const;
export type AttendanceStatus = (typeof ATTENDANCE_STATUSES)[number];

export type InAppNotification = {
  notificationId: string;
  audience: string;
  title: string;
  body: string;
  type: string;
  data: Record<string, string>;
};

export const AcademyEventIds = {
  attendanceAbsence: (attendanceDocumentId: string): string =>
    `attendance_absence_${attendanceDocumentId}`,
  homeworkAssigned: (assignmentId: string): string =>
    `homework_assigned_${assignmentId}`,
  homeworkReviewed: (recitationRecordId: string): string =>
    `homework_reviewed_${recitationRecordId}`,
  halaqaActivityPublished: (activityId: string, studentId: string): string =>
    `halaqa_activity_published_${activityId}_${studentId}`,
};

export function notificationId(observerId: string, eventId: string): string {
  return `${observerId.trim()}_${eventId.trim()}`;
}

/** Role broadcasts — not a user document. */
export const ROLE_NOTIFICATION_AUDIENCES = [
  "all",
  "admin",
  "supervisor",
  "teacher",
  "parent",
  "student",
] as const;

/**
 * Matches Firestore `hasActiveProfile`: missing `isActive` is legacy-active;
 * `isActive == false` or a pending first-login password change is not eligible
 * to receive a notification. A missing user document fails closed.
 */
export function isEligibleNotificationRecipient(
  user: Record<string, unknown> | undefined,
): boolean {
  if (!user) return false;
  if (user.isActive === false) return false;
  if (user.passwordChangeRequired === true) return false;
  return true;
}

const STUDENT_FALLBACK_LABEL = "الطالب";

function label(studentName: string | undefined): string {
  const trimmed = (studentName ?? "").trim();
  return trimmed === "" ? STUDENT_FALLBACK_LABEL : trimmed;
}

/** `YYYY-MM-DD` → `DD/MM/YYYY` (Dart formatDateDmy). */
export function formatDateDmy(ymd: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd.trim());
  if (!m) return ymd;
  return `${m[3]}/${m[2]}/${m[1]}`;
}

function statusLabel(status: string): string {
  return status === "late" ? "متأخر" : "حاضر";
}

// ── Attendance absence (observers: linked parents only) ─────────────────

export type AbsenceTransition =
  | {
      kind: "absent";
      studentId: string;
      attendanceDocumentId: string;
    }
  | {
      kind: "corrected";
      studentId: string;
      attendanceDocumentId: string;
      correctedToStatus: string;
    };

/**
 * Mirrors AttendanceAbsenceTransitions.project: only the explicit `absent`
 * wire value opens an absence fact; leaving it for present/late/excused is a
 * correction. Anything else produces no fact.
 */
export function projectAbsenceTransitions(params: {
  previousStatusByStudentId: ReadonlyMap<string, string | undefined>;
  marks: readonly { studentId: string; status: string; attendanceDocumentId: string }[];
}): AbsenceTransition[] {
  const out: AbsenceTransition[] = [];
  for (const mark of params.marks) {
    const previous = (params.previousStatusByStudentId.get(mark.studentId) ?? "").trim();
    const current = mark.status.trim();
    const prevAbsent = previous === "absent";
    const currAbsent = current === "absent";
    if (!prevAbsent && currAbsent) {
      out.push({
        kind: "absent",
        studentId: mark.studentId,
        attendanceDocumentId: mark.attendanceDocumentId,
      });
      continue;
    }
    if (prevAbsent && !currAbsent) {
      if (current !== "present" && current !== "late" && current !== "excused") {
        continue;
      }
      out.push({
        kind: "corrected",
        studentId: mark.studentId,
        attendanceDocumentId: mark.attendanceDocumentId,
        correctedToStatus: current,
      });
    }
  }
  return out;
}

export function buildAbsenceNotification(params: {
  parentId: string;
  transition: AbsenceTransition;
  studentName?: string;
  halaqaId: string;
  sessionId: string;
  dateYmd: string;
}): InAppNotification {
  const { transition } = params;
  const eventId = AcademyEventIds.attendanceAbsence(transition.attendanceDocumentId);
  const name = label(params.studentName);
  const date = formatDateDmy(params.dateYmd);
  const isAbsent = transition.kind === "absent";
  return {
    notificationId: notificationId(params.parentId, eventId),
    audience: params.parentId,
    title: isAbsent ? "تم تسجيل غياب" : "تم تحديث الحضور",
    body: isAbsent
      ? `تم تسجيل غياب ${name} بتاريخ ${date}`
      : `تم تحديث حالة ${name} بتاريخ ${date} إلى ${statusLabel(
          transition.correctedToStatus,
        )}`,
    type: NOTIFICATION_TYPE_ATTENDANCE,
    data: {
      kind: "attendance",
      eventId,
      studentId: transition.studentId,
      halaqaId: params.halaqaId,
      sessionId: params.sessionId,
      attendanceId: transition.attendanceDocumentId,
    },
  };
}

// ── Homework assigned (observers: subject student + linked parents) ──────

export function buildHomeworkAssignedNotification(params: {
  observerId: string;
  assignmentId: string;
  studentId: string;
  halaqaId: string;
  studentName?: string;
  newMemorizationRange: string;
  reviewRange: string;
}): InAppNotification {
  const eventId = AcademyEventIds.homeworkAssigned(params.assignmentId);
  const forStudent = params.observerId === params.studentId;
  const rangeHint =
    params.newMemorizationRange.trim() !== ""
      ? params.newMemorizationRange.trim()
      : params.reviewRange.trim();
  let body: string;
  if (forStudent) {
    body =
      rangeHint === ""
        ? "لديك تكليف جديد — افتح واجباتي"
        : `تكليف جديد: ${rangeHint} — افتح واجباتي`;
  } else {
    const name = label(params.studentName);
    body =
      rangeHint === ""
        ? `تم تعيين تكليف جديد لـ ${name}`
        : `تم تعيين تكليف لـ ${name}: ${rangeHint}`;
  }
  return {
    notificationId: notificationId(params.observerId, eventId),
    audience: params.observerId,
    title: "تكليف جديد",
    body,
    type: NOTIFICATION_TYPE_ASSIGNMENT,
    data: {
      kind: "homework_assigned",
      eventId,
      assignmentId: params.assignmentId,
      studentId: params.studentId,
      halaqaId: params.halaqaId,
    },
  };
}

// ── Homework reviewed (observers: subject student + linked parents) ──────

export function buildHomeworkReviewedNotification(params: {
  observerId: string;
  recordId: string;
  studentId: string;
  halaqaId: string;
  studentName?: string;
  grade: string;
}): InAppNotification {
  const eventId = AcademyEventIds.homeworkReviewed(params.recordId);
  const forStudent = params.observerId === params.studentId;
  const grade = params.grade.trim();
  const name = label(params.studentName);
  return {
    notificationId: notificationId(params.observerId, eventId),
    audience: params.observerId,
    title: forStudent ? "تم تقييم تسميعك" : "تم تقييم التسميع",
    body: forStudent
      ? "راجع صفحة التقييمات لمعرفة الدرجة والملاحظات"
      : grade === ""
        ? `تم تقييم تسميع ${name}`
        : `تم تقييم تسميع ${name}: ${grade}`,
    type: NOTIFICATION_TYPE_ASSIGNMENT,
    data: {
      kind: "homework_reviewed",
      eventId,
      evaluationId: params.recordId,
      studentId: params.studentId,
      halaqaId: params.halaqaId,
    },
  };
}

// ── Halaqa activity (observers: each roster student + linked parents) ────

const ACTIVITY_PREVIEW_LENGTH = 60;

export function buildActivityPublishedNotification(params: {
  observerId: string;
  activityId: string;
  studentId: string;
  halaqaId: string;
  studentName?: string;
  prompt: string;
}): InAppNotification {
  const eventId = AcademyEventIds.halaqaActivityPublished(
    params.activityId,
    params.studentId,
  );
  const forStudent = params.observerId === params.studentId;
  const preview = params.prompt.trim();
  const clipped =
    preview.length > ACTIVITY_PREVIEW_LENGTH
      ? `${preview.substring(0, ACTIVITY_PREVIEW_LENGTH)}…`
      : preview;
  let body: string;
  if (forStudent) {
    body =
      clipped === ""
        ? "مهمة جديدة من معلم الحلقة — افتح أنشطة الحلقة"
        : `مهمة جديدة: ${clipped}`;
  } else {
    const name = label(params.studentName);
    body = clipped === "" ? `مهمة جديدة لـ ${name}` : `مهمة جديدة لـ ${name}: ${clipped}`;
  }
  return {
    notificationId: notificationId(params.observerId, eventId),
    audience: params.observerId,
    title: "مهمة جديدة للحلقة",
    body,
    type: NOTIFICATION_TYPE_ASSIGNMENT,
    data: {
      kind: "halaqa_activity",
      eventId,
      activityId: params.activityId,
      studentId: params.studentId,
      halaqaId: params.halaqaId,
    },
  };
}

/**
 * Homework submission (assignment-linked recitation) moved from `pending` to
 * `reviewed`. Live teacher evaluations keep the WA-13 parent push chain.
 */
export function decideHomeworkReviewed(params: {
  before: Record<string, unknown> | null | undefined;
  after: Record<string, unknown> | null | undefined;
}): { notify: false } | { notify: true; studentId: string; halaqaId: string; grade: string } {
  const { before, after } = params;
  if (!before || !after) return { notify: false };
  const text = (v: unknown): string => (typeof v === "string" ? v.trim() : "");
  if (text(after.assignmentId) === "") return { notify: false };
  if (text(before.reviewStatus) !== "pending") return { notify: false };
  if (text(after.reviewStatus) !== "reviewed") return { notify: false };
  const studentId = text(after.studentId);
  if (studentId === "") return { notify: false };
  return {
    notify: true,
    studentId,
    halaqaId: text(after.halaqaId),
    grade: text(after.grade),
  };
}
