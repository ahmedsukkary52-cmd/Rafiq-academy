/**
 * Parent absence (permission) requests → staff and parent notifications.
 *
 * Recipients are re-derived from `halaqat/{halaqaId}` (teacherId,
 * supervisorId, roster) and the request author is re-checked against
 * `parentProfiles.childrenIds`, so a forged request cannot address anyone.
 * Notification ids are deterministic: a retried trigger rewrites the same
 * documents instead of duplicating them.
 */

import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

import { stringList } from "../authority/callerContext";
import { formatDateDmy, type InAppNotification } from "./academyNotifications";
import { loadStudentNames, writeInAppNotifications } from "./academyNotificationStore";
import { pushGateBlockedMessage, resolvePushSendMode } from "./pushGate";

export const NOTIFICATION_TYPE_ABSENCE_REQUEST = "absence_request";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Firestore Timestamp | Date | ISO string → `YYYY-MM-DD` (UTC+2 academy day). */
export function requestDayKey(raw: unknown): string {
  let date: Date | null = null;
  if (raw && typeof raw === "object" && typeof (raw as { toDate?: unknown }).toDate === "function") {
    date = (raw as { toDate: () => Date }).toDate();
  } else if (raw instanceof Date) {
    date = raw;
  } else if (typeof raw === "string" && raw.trim() !== "") {
    const parsed = new Date(raw);
    if (!Number.isNaN(parsed.getTime())) date = parsed;
  }
  if (!date) return "";
  const shifted = new Date(date.getTime() + 2 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

export type AbsenceFanOutResult = { written: number; skipped?: string };

export async function fanOutAbsenceRequestCreated(
  db: admin.firestore.Firestore,
  requestId: string,
  data: Record<string, unknown>,
): Promise<AbsenceFanOutResult> {
  const halaqaId = text(data.halaqaId);
  const studentId = text(data.studentId);
  const parentId = text(data.requestedBy);
  if (!halaqaId || !studentId || !parentId) return { written: 0, skipped: "missing_identity" };

  const [halaqaSnap, parentSnap] = await Promise.all([
    db.collection("halaqat").doc(halaqaId).get(),
    db.collection("parentProfiles").doc(parentId).get(),
  ]);
  if (!halaqaSnap.exists) return { written: 0, skipped: "halaqa_missing" };
  if (!stringList(parentSnap.data()?.childrenIds).includes(studentId)) {
    return { written: 0, skipped: "parent_not_linked" };
  }
  const halaqa = halaqaSnap.data() ?? {};
  if (!stringList(halaqa.studentIds).includes(studentId)) {
    return { written: 0, skipped: "student_not_on_roster" };
  }

  const staff = [...new Set([text(halaqa.teacherId), text(halaqa.supervisorId)].filter(Boolean))];
  if (staff.length === 0) return { written: 0, skipped: "no_staff" };
  const names = await loadStudentNames(db, [studentId]);
  const student = names.get(studentId) ?? "طالب";
  const day = requestDayKey(data.date);
  const halaqaName = text(halaqa.name);
  const notifications: InAppNotification[] = staff.map((uid) => ({
    notificationId: `${uid}_absence_request_${requestId}`,
    audience: uid,
    title: "طلب استئذان جديد",
    body: `ولي أمر ${student} يطلب الإذن بالغياب${day ? ` يوم ${formatDateDmy(day)}` : ""}${halaqaName ? ` — ${halaqaName}` : ""}`,
    type: NOTIFICATION_TYPE_ABSENCE_REQUEST,
    data: { requestId, halaqaId, studentId },
  }));
  return { written: await writeInAppNotifications(db, notifications) };
}

export async function notifyAbsenceRequestReviewed(
  db: admin.firestore.Firestore,
  requestId: string,
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Promise<AbsenceFanOutResult> {
  const status = text(after.status);
  if (text(before.status) === status) return { written: 0, skipped: "status_unchanged" };
  if (status !== "approved" && status !== "rejected") return { written: 0, skipped: "not_reviewed" };
  const parentId = text(after.requestedBy);
  const studentId = text(after.studentId);
  if (!parentId || !studentId) return { written: 0, skipped: "missing_identity" };
  const names = await loadStudentNames(db, [studentId]);
  const student = names.get(studentId) ?? "الطالب";
  const day = requestDayKey(after.date);
  return {
    written: await writeInAppNotifications(db, [
      {
        notificationId: `${parentId}_absence_request_reviewed_${requestId}`,
        audience: parentId,
        title: status === "approved" ? "تمت الموافقة على طلب الاستئذان" : "تم رفض طلب الاستئذان",
        body: `طلب غياب ${student}${day ? ` يوم ${formatDateDmy(day)}` : ""}`,
        type: NOTIFICATION_TYPE_ABSENCE_REQUEST,
        data: { requestId, studentId },
      },
    ]),
  };
}

export const notifyOnAbsenceRequestCreated = onDocumentCreated(
  { region: "europe-west1", document: "absenceRequests/{requestId}" },
  async (event) => {
    if (resolvePushSendMode() === "blocked") {
      console.warn(pushGateBlockedMessage("notifyOnAbsenceRequestCreated"));
      return;
    }
    const data = event.data?.data();
    if (!data) return;
    await fanOutAbsenceRequestCreated(admin.firestore(), event.params.requestId, data);
  },
);

export const notifyOnAbsenceRequestReviewed = onDocumentUpdated(
  { region: "europe-west1", document: "absenceRequests/{requestId}" },
  async (event) => {
    if (resolvePushSendMode() === "blocked") {
      console.warn(pushGateBlockedMessage("notifyOnAbsenceRequestReviewed"));
      return;
    }
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    await notifyAbsenceRequestReviewed(admin.firestore(), event.params.requestId, before, after);
  },
);
