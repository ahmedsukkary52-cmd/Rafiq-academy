/**
 * PH-02 / C6 + D7 + D10 — attendance and live evaluation are written only by
 * these callables. Every new record binds to a real `sessions/{id}` document;
 * legacy synthetic `{halaqaId}_yyyyMMdd` ids are never produced or accepted.
 */

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import {
  actorForCallerRole,
  adminActor,
  buildAuditLogEntry,
} from "../audit/auditLogWrite";
import {
  loadCallerRole,
  optionalText,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { cairoYmd, normalizeCairoYmd } from "../billing/cairoTime";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import {
  ATTENDANCE_STATUSES,
  buildAbsenceNotification,
  projectAbsenceTransitions,
} from "../notifications/academyNotifications";
import {
  loadParentIdsByStudent,
  writeInAppNotifications,
} from "../notifications/academyNotificationStore";
import { assertBackendAllowed } from "../productionGate";
import { ASSISTANT_TEACHER_ROLE, isActiveCoverOf } from "../staff/halaqaAssistantFunctions";
import { materializeSessionCore } from "./materializeSession";
import {
  attendanceDocId,
  cairoDayRange,
  EVALUATION_TYPES,
  EvaluationType,
  evaluationDocId,
  GRADE_LABELS,
  isLegacySyntheticSessionId,
  isWithinAttendanceWindow,
  isWithinTeacherEditWindow,
  MAX_ATTENDANCE_MARKS,
  MAX_EVALUATION_NOTES_LENGTH,
  operationalDay,
  operationalSlotsForDate,
} from "./sessionRecords";

export const NOT_ATTENDED_MESSAGE =
  "لا يمكن تقييم الطالب إلا بعد تسجيل حضوره (حاضر أو متأخر) في هذه الجلسة";

export const TEACHER_EDIT_WINDOW_CLOSED_MESSAGE =
  "انتهت مهلة تعديل التقييم (24 ساعة) — التصحيح متاح للمسؤول فقط";

/** Server-persisted creation anchor of an evaluation (B1). */
function evaluationCreatedAt(data: Record<string, unknown> | undefined): Date | null {
  const raw = data?.createdAt;
  return raw instanceof Timestamp ? raw.toDate() : null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function requireCairoDate(raw: unknown): string {
  try {
    return normalizeCairoYmd(requireText(raw, "date", 10));
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    throw new HttpsError(
      "invalid-argument",
      "date يجب أن يكون تاريخ القاهرة بصيغة YYYY-MM-DD",
    );
  }
}

type AttendanceMark = { studentId: string; status: string };

function parseMarks(raw: unknown): AttendanceMark[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpsError("invalid-argument", "marks مطلوبة");
  }
  if (raw.length > MAX_ATTENDANCE_MARKS) {
    throw new HttpsError("invalid-argument", "عدد سجلات الحضور كبير جداً");
  }
  const seen = new Set<string>();
  return raw.map((entry) => {
    const obj = (entry ?? {}) as Record<string, unknown>;
    const studentId = requireText(obj.studentId, "studentId");
    const status = text(obj.status);
    if (!(ATTENDANCE_STATUSES as readonly string[]).includes(status)) {
      throw new HttpsError("invalid-argument", "حالة الحضور غير صالحة");
    }
    if (seen.has(studentId)) {
      throw new HttpsError("invalid-argument", "طالب مكرر في سجل الحضور");
    }
    seen.add(studentId);
    return { studentId, status };
  });
}

function mapScheduleError(err: unknown): never {
  if (err instanceof HttpsError) throw err;
  const message = err instanceof Error ? err.message : String(err);
  if (message.includes("slotId is required")) {
    throw new HttpsError(
      "failed-precondition",
      "مواعيد الحلقة بلا slotId — يلزم تشغيل ترحيل المواعيد (WA-7) أولاً",
    );
  }
  throw new HttpsError("failed-precondition", "جدول الحلقة غير صالح");
}

export type RecordAttendanceResult = {
  sessionId: string;
  date: string;
  savedCount: number;
  retiredCount: number;
  notificationCount: number;
  correction: boolean;
};

/**
 * Teacher of the halaqa, within the operational-day window; Admin may also
 * correct a past day (audited as `attendance_correct`).
 */
export async function recordSessionAttendanceCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  now: Date = new Date(),
): Promise<RecordAttendanceResult> {
  const uid = requireCallerUid(callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId");
  const date = requireCairoDate(data.date);
  const marks = parseMarks(data.marks);

  const role = await loadCallerRole(db, uid);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);
  const halaqaSnap = await halaqaRef.get();
  if (!halaqaSnap.exists) {
    throw new HttpsError("not-found", "الحلقة غير موجودة");
  }
  const halaqa = halaqaSnap.data() ?? {};
  const isAdmin = role === "admin";
  const isHalaqaTeacher = role === "teacher" && text(halaqa.teacherId) === uid;
  const isCover = !isHalaqaTeacher && isActiveCoverOf(halaqa, uid, role);
  if (!isAdmin && !isHalaqaTeacher && !isCover) {
    throw new HttpsError("permission-denied", "تسجيل الحضور متاح لمعلّم الحلقة فقط");
  }

  let day: ReturnType<typeof operationalDay> = null;
  try {
    day = operationalDay(operationalSlotsForDate(halaqa.schedule, date));
  } catch (err) {
    mapScheduleError(err);
  }
  if (!day) {
    throw new HttpsError(
      "failed-precondition",
      "لا توجد جلسة مجدولة للحلقة في هذا اليوم",
    );
  }

  if (date > cairoYmd(now)) {
    throw new HttpsError(
      "failed-precondition",
      "لا يمكن تسجيل حضور جلسة لم يحن يومها",
    );
  }
  const withinWindow = isWithinAttendanceWindow({
    now,
    dateYmd: date,
    dayEndAt: day.endAt,
  });
  if (!withinWindow && !isAdmin) {
    throw new HttpsError(
      "failed-precondition",
      "انتهت نافذة تعديل الحضور لهذه الجلسة",
    );
  }
  const correction = !withinWindow;

  const { sessionId } = await materializeSessionCore(db, uid, {
    halaqaId,
    slotId: day.primarySlotId,
    date,
  });

  const range = cairoDayRange(date);
  const sessionRef = db.collection("sessions").doc(sessionId);
  const markedIds = new Set(marks.map((m) => m.studentId));

  const txResult = await db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new HttpsError("failed-precondition", "الجلسة غير موجودة");
    }
    const session = sessionSnap.data() ?? {};
    if (text(session.halaqaId) !== halaqaId) {
      throw new HttpsError("failed-precondition", "الجلسة لا تخص هذه الحلقة");
    }
    if (session.status === "cancelled") {
      throw new HttpsError("failed-precondition", "الجلسة ملغاة");
    }

    const fresh = (await tx.get(halaqaRef)).data() ?? {};
    const freshCover = isCover && isActiveCoverOf(fresh, uid, role);
    if (!isAdmin && !freshCover && text(fresh.teacherId) !== uid) {
      throw new HttpsError("permission-denied", "تسجيل الحضور متاح لمعلّم الحلقة فقط");
    }
    const roster = new Set(stringList(fresh.studentIds));
    for (const mark of marks) {
      if (!roster.has(mark.studentId)) {
        throw new HttpsError(
          "invalid-argument",
          `الطالب ${mark.studentId} ليس ضمن طلاب الحلقة`,
        );
      }
    }

    const daySnap = await tx.get(
      db
        .collection("attendanceRecords")
        .where("halaqaId", "==", halaqaId)
        .where("date", ">=", Timestamp.fromDate(range.start))
        .where("date", "<", Timestamp.fromDate(range.end)),
    );
    const userSnaps = await tx.getAll(
      ...marks.map((m) => db.collection("users").doc(m.studentId)),
    );
    const names = new Map<string, string>();
    for (const snap of userSnaps) {
      names.set(snap.id, text(snap.data()?.name));
    }

    // Pre-save status per student; the canonical doc of this session wins.
    const previous = new Map<string, string | undefined>();
    const canonical = new Set<string>();
    for (const doc of daySnap.docs) {
      const d = doc.data();
      const studentId = text(d.studentId);
      if (!studentId) continue;
      const isCanonical = doc.id === attendanceDocId(sessionId, studentId);
      if (canonical.has(studentId) && !isCanonical) continue;
      previous.set(studentId, typeof d.status === "string" ? d.status : undefined);
      if (isCanonical) canonical.add(studentId);
    }

    const dateTs = Timestamp.fromDate(range.start);
    for (const mark of marks) {
      tx.set(
        db.collection("attendanceRecords").doc(attendanceDocId(sessionId, mark.studentId)),
        {
          studentId: mark.studentId,
          studentName: names.get(mark.studentId) ?? "",
          halaqaId,
          date: dateTs,
          status: mark.status,
          recordedBy: uid,
          sessionId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    if (freshCover) {
      // The session keeps the primary teacherId; this records who taught it.
      tx.update(sessionRef, {
        handledBy: uid,
        handledAs: "cover",
        coverId: text(fresh.coverId),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Same-day legacy duplicates of re-marked students are superseded by the
    // canonical session doc (other days are never touched).
    let retired = 0;
    for (const doc of daySnap.docs) {
      const studentId = text(doc.data().studentId);
      if (!markedIds.has(studentId)) continue;
      if (doc.id === attendanceDocId(sessionId, studentId)) continue;
      tx.delete(doc.ref);
      retired += 1;
    }

    if (correction) {
      tx.set(
        db.collection(AUDIT_LOGS_COLLECTION).doc(),
        buildAuditLogEntry(
          {
            actor: adminActor(uid),
            action: AUDIT_ACTION.attendanceCorrect,
            targetType: AUDIT_TARGET_TYPE.session,
            targetId: sessionId,
            metadata: { halaqaId, sessionId, date, updatedCount: marks.length },
            source: "recordSessionAttendance",
          },
          FieldValue.serverTimestamp(),
        ),
      );
    }

    return { previous, names, retired };
  });

  const transitions = projectAbsenceTransitions({
    previousStatusByStudentId: txResult.previous,
    marks: marks.map((m) => ({
      studentId: m.studentId,
      status: m.status,
      attendanceDocumentId: attendanceDocId(sessionId, m.studentId),
    })),
  });

  let notificationCount = 0;
  if (transitions.length > 0) {
    const parents = await loadParentIdsByStudent(
      db,
      transitions.map((t) => t.studentId),
    );
    notificationCount = await writeInAppNotifications(
      db,
      transitions.flatMap((transition) =>
        (parents.get(transition.studentId) ?? []).map((parentId) =>
          buildAbsenceNotification({
            parentId,
            transition,
            studentName: txResult.names.get(transition.studentId),
            halaqaId,
            sessionId,
            dateYmd: date,
          }),
        ),
      ),
    );
  }

  return {
    sessionId,
    date,
    savedCount: marks.length,
    retiredCount: txResult.retired,
    notificationCount,
    correction,
  };
}

function parseEvaluationType(raw: unknown): EvaluationType {
  const value = text(raw);
  if ((EVALUATION_TYPES as readonly string[]).includes(value)) {
    return value as EvaluationType;
  }
  throw new HttpsError("invalid-argument", "نوع التقييم غير صالح");
}

function parseGrade(raw: unknown, field: string): string {
  const label = GRADE_LABELS[text(raw)];
  if (!label) {
    throw new HttpsError("invalid-argument", `${field} غير صالح`);
  }
  return label;
}

/**
 * The real session for a student's day comes from that student's attendance
 * mark (never from a client-built day id).
 */
async function resolveAttendedSessionId(
  db: admin.firestore.Firestore,
  params: { halaqaId: string; studentId: string; date: string },
): Promise<string> {
  const range = cairoDayRange(params.date);
  const snap = await db
    .collection("attendanceRecords")
    .where("halaqaId", "==", params.halaqaId)
    .where("studentId", "==", params.studentId)
    .where("date", ">=", Timestamp.fromDate(range.start))
    .where("date", "<", Timestamp.fromDate(range.end))
    .get();
  for (const doc of snap.docs) {
    const sessionId = text(doc.data().sessionId);
    if (!sessionId || isLegacySyntheticSessionId(sessionId)) continue;
    const session = await db.collection("sessions").doc(sessionId).get();
    if (session.exists && text(session.data()?.halaqaId) === params.halaqaId) {
      return sessionId;
    }
  }
  throw new HttpsError("failed-precondition", NOT_ATTENDED_MESSAGE);
}

export type UpsertEvaluationResult = {
  evaluationId: string;
  sessionId: string;
  retiredCount: number;
};

/**
 * Live evaluation create / correct (D7: Present/Late only, checked
 * transactionally).
 *
 * - Teacher of the halaqa: create, and edit while the evaluation is younger
 *   than 24h (B1). The anchor is the server-set `createdAt`; nothing in the
 *   request can move it.
 * - Admin: create or correct at any time, including after the Teacher window
 *   (B2), under the same session / roster / attendance gates.
 * - Supervisor and every other role: denied (spec §10.1, W6 Rule 1/6).
 *
 * [now] is the server clock; the callable wrapper never takes it from input.
 */
export async function upsertSessionEvaluationCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  now: Date = new Date(),
): Promise<UpsertEvaluationResult> {
  const uid = requireCallerUid(callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId");
  const studentId = requireText(data.studentId, "studentId");
  const type = parseEvaluationType(data.type);
  const grade = parseGrade(data.grade, "grade");
  const behaviorGrade = parseGrade(data.behaviorGrade, "behaviorGrade");
  const notes = optionalText(data.notes, MAX_EVALUATION_NOTES_LENGTH);
  const notesViolation = contactInfoViolation(notes);
  if (notesViolation) {
    throw new HttpsError("invalid-argument", notesViolation);
  }

  const role = await loadCallerRole(db, uid);
  const isAdmin = role === "admin";
  if (role !== "teacher" && role !== ASSISTANT_TEACHER_ROLE && !isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "التقييم متاح لمعلّم الحلقة، والتصحيح للمسؤول فقط",
    );
  }

  const requested = text(data.sessionId);
  if (requested && isLegacySyntheticSessionId(requested)) {
    throw new HttpsError(
      "invalid-argument",
      "معرّف الجلسة ليس جلسة حقيقية — لا تُقبل معرفات اليوم القديمة",
    );
  }
  const sessionId =
    requested ||
    (await resolveAttendedSessionId(db, {
      halaqaId,
      studentId,
      date: requireCairoDate(data.date),
    }));

  return db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(db.collection("sessions").doc(sessionId));
    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "الجلسة غير موجودة");
    }
    const session = sessionSnap.data() ?? {};
    if (text(session.halaqaId) !== halaqaId) {
      throw new HttpsError("failed-precondition", "الجلسة لا تخص هذه الحلقة");
    }
    if (session.status === "cancelled") {
      throw new HttpsError("failed-precondition", "الجلسة ملغاة");
    }

    const halaqaSnap = await tx.get(db.collection("halaqat").doc(halaqaId));
    if (!halaqaSnap.exists) {
      throw new HttpsError("not-found", "الحلقة غير موجودة");
    }
    const halaqa = halaqaSnap.data() ?? {};
    const isPrimary = role === "teacher" && text(halaqa.teacherId) === uid;
    const isCover = !isPrimary && isActiveCoverOf(halaqa, uid, role);
    if (!isAdmin && !isPrimary && !isCover) {
      throw new HttpsError("permission-denied", "التقييم متاح لمعلّم الحلقة فقط");
    }
    if (!stringList(halaqa.studentIds).includes(studentId)) {
      throw new HttpsError("invalid-argument", "الطالب ليس ضمن طلاب الحلقة");
    }

    const attendanceSnap = await tx.get(
      db.collection("attendanceRecords").doc(attendanceDocId(sessionId, studentId)),
    );
    const attended = ["present", "late"].includes(text(attendanceSnap.data()?.status));
    if (!attendanceSnap.exists || !attended) {
      throw new HttpsError("failed-precondition", NOT_ATTENDED_MESSAGE);
    }

    let range: { start: Date; end: Date };
    try {
      range = cairoDayRange(text(session.date));
    } catch {
      throw new HttpsError("failed-precondition", "تاريخ الجلسة غير صالح");
    }
    const evaluationId = evaluationDocId(sessionId, studentId, type);
    const evaluationRef = db.collection("recitationRecords").doc(evaluationId);
    const priorSnap = await tx.get(evaluationRef);
    const prior = priorSnap.data();
    if (
      priorSnap.exists &&
      (text(prior?.assignmentId) !== "" ||
        text(prior?.reviewStatus) === "pending" ||
        text(prior?.sessionId) !== sessionId)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "يوجد سجل غير تقييم مباشر بنفس المعرّف — لا يمكن استبداله",
      );
    }
    if (
      priorSnap.exists &&
      !isAdmin &&
      !isWithinTeacherEditWindow(evaluationCreatedAt(prior), now)
    ) {
      throw new HttpsError("failed-precondition", TEACHER_EDIT_WINDOW_CLOSED_MESSAGE);
    }
    const sameDaySnap = await tx.get(
      db
        .collection("recitationRecords")
        .where("halaqaId", "==", halaqaId)
        .where("studentId", "==", studentId)
        .where("date", ">=", Timestamp.fromDate(range.start))
        .where("date", "<", Timestamp.fromDate(range.end)),
    );
    const userSnap = await tx.get(db.collection("users").doc(studentId));
    // D11 gap: the client does not send a verses range yet.
    const versesRange = "";

    // An Admin correction keeps the evaluation owned by the halaqa Teacher.
    const teacherId = isAdmin
      ? text(prior?.teacherId) || text(halaqa.teacherId)
      : uid;

    tx.set(
      evaluationRef,
      {
        studentId,
        studentName: text(userSnap.data()?.name),
        teacherId,
        // B1 anchor: written once, by the server, on first create only.
        ...(priorSnap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
        halaqaId,
        date: Timestamp.fromDate(range.start),
        type,
        versesRange,
        sessionId,
        grade,
        behaviorGrade,
        notes: notes ? notes : FieldValue.delete(),
        reviewStatus: "reviewed",
        ...(isCover ? { handledAs: "cover", coverId: text(halaqa.coverId) } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // Retire same-day legacy duplicates of this live evaluation only — never
    // homework submissions (assignment-linked or pending).
    let retired = 0;
    for (const doc of sameDaySnap.docs) {
      const d = doc.data();
      if (doc.id === evaluationId) continue;
      if (text(d.type) !== type) continue;
      if (text(d.assignmentId) !== "") continue;
      if (text(d.reviewStatus) === "pending") continue;
      tx.delete(doc.ref);
      retired += 1;
    }

    // Spec §20.1 / C16: one audit per real create or correction (change-only,
    // so an identical replay appends nothing). Actor role comes from
    // users/{uid}.role, never from the request.
    const changed =
      !priorSnap.exists ||
      text(prior?.grade) !== grade ||
      text(prior?.behaviorGrade) !== behaviorGrade ||
      text(prior?.notes) !== notes ||
      text(prior?.sessionId) !== sessionId;
    if (changed || retired > 0) {
      tx.set(
        db.collection(AUDIT_LOGS_COLLECTION).doc(),
        buildAuditLogEntry(
          {
            actor: actorForCallerRole(uid, role),
            action: AUDIT_ACTION.evaluationCreateOrCorrect,
            targetType: AUDIT_TARGET_TYPE.evaluation,
            targetId: evaluationId,
            metadata: {
              sessionId,
              halaqaId,
              studentId,
              evaluationType: type,
              versesRange,
              operation: priorSnap.exists ? "correct" : "create",
            },
            source: "upsertSessionEvaluation",
          },
          FieldValue.serverTimestamp(),
        ),
      );
    }

    return { evaluationId, sessionId, retiredCount: retired };
  });
}

export const recordSessionAttendance = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("recordSessionAttendance");
    return recordSessionAttendanceCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

export const upsertSessionEvaluation = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("upsertSessionEvaluation");
    return upsertSessionEvaluationCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
