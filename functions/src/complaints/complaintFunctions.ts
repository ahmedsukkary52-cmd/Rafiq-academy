/**
 * Complaints lifecycle (server-authoritative).
 *
 * `complaints/{id}` is created only here: the caller's identity, role and
 * context (child / halaqa) are resolved from relationships, never trusted
 * from the client. Every reply and status change is appended to
 * `complaints/{id}/history` so the thread is never overwritten. Admins are
 * notified through the role audience (`audience: 'admin'`); the complainant
 * is notified on every admin reply or status change.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  loadCallerRole,
  optionalText,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import type { InAppNotification } from "../notifications/academyNotifications";
import { writeInAppNotifications } from "../notifications/academyNotificationStore";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";

export const COMPLAINTS_COLLECTION = "complaints";
export const COMPLAINT_HISTORY_SUBCOLLECTION = "history";
export const NOTIFICATION_TYPE_COMPLAINT = "complaint";

export const COMPLAINT_SENDER_ROLES = ["parent", "teacher", "supervisor"] as const;
export const COMPLAINT_STATUSES = ["open", "in_progress", "resolved", "archived"] as const;
export type ComplaintStatus = (typeof COMPLAINT_STATUSES)[number];

export const COMPLAINT_SUBJECT_MAX = 120;
export const COMPLAINT_MESSAGE_MAX = 2000;

export function parseComplaintStatus(raw: unknown): ComplaintStatus | null {
  if (raw == null || raw === "") return null;
  if (typeof raw === "string" && (COMPLAINT_STATUSES as readonly string[]).includes(raw)) {
    return raw as ComplaintStatus;
  }
  throw new HttpsError("invalid-argument", "حالة الشكوى غير صالحة");
}

function rejectContactInfo(...texts: string[]): void {
  for (const text of texts) {
    const violation = contactInfoViolation(text);
    if (violation) throw new HttpsError("invalid-argument", violation);
  }
}

async function loadName(db: admin.firestore.Firestore, uid: string): Promise<string> {
  const snap = await db.collection("users").doc(uid).get();
  const name = snap.data()?.name;
  return typeof name === "string" ? name.trim() : "";
}

export type SubmitComplaintResult = { complaintId: string };

export async function submitComplaintCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<SubmitComplaintResult> {
  const uid = requireCallerUid(callerUid);
  const role = await loadCallerRole(db, uid);
  if (!(COMPLAINT_SENDER_ROLES as readonly string[]).includes(role)) {
    throw new HttpsError("permission-denied", "تقديم الشكاوى متاح لأولياء الأمور والمعلمين والمشرفين");
  }
  const subject = requireText(data.subject, "عنوان الشكوى", COMPLAINT_SUBJECT_MAX);
  const message = requireText(data.message, "نص الشكوى", COMPLAINT_MESSAGE_MAX);
  rejectContactInfo(subject, message);

  const studentId = optionalText(data.studentId, 128);
  const halaqaId = optionalText(data.halaqaId, 128);
  let context: { studentId: string | null; halaqaId: string | null; studentName: string; halaqaName: string } = {
    studentId: null,
    halaqaId: null,
    studentName: "",
    halaqaName: "",
  };

  if (studentId) {
    if (role !== "parent") {
      throw new HttpsError("invalid-argument", "ربط الشكوى بطالب متاح لولي الأمر فقط");
    }
    const parent = await db.collection("parentProfiles").doc(uid).get();
    if (!stringList(parent.data()?.childrenIds).includes(studentId)) {
      throw new HttpsError("permission-denied", "الطالب غير مرتبط بحسابك");
    }
    context = { ...context, studentId, studentName: await loadName(db, studentId) };
  }
  if (halaqaId) {
    const halaqa = await db.collection("halaqat").doc(halaqaId).get();
    const h = halaqa.data();
    const allowed =
      halaqa.exists &&
      ((role === "teacher" && h?.teacherId === uid) ||
        (role === "supervisor" && h?.supervisorId === uid) ||
        (role === "parent" && studentId !== "" && stringList(h?.studentIds).includes(studentId)));
    if (!allowed) {
      throw new HttpsError("permission-denied", "لا تملك صلاحية على هذه الحلقة");
    }
    const name = h?.name;
    context = { ...context, halaqaId, halaqaName: typeof name === "string" ? name : "" };
  }

  const senderName = await loadName(db, uid);
  const ref = db.collection(COMPLAINTS_COLLECTION).doc();
  const batch = db.batch();
  batch.set(ref, {
    senderId: uid,
    senderRole: role,
    senderName,
    subject,
    message,
    studentId: context.studentId,
    studentName: context.studentName,
    halaqaId: context.halaqaId,
    halaqaName: context.halaqaName,
    status: "open",
    historyCount: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  await writeInAppNotifications(db, [
    {
      notificationId: `admin_complaint_created_${ref.id}`,
      audience: "admin",
      title: "شكوى جديدة",
      body: `${senderName || "مستخدم"}: ${subject}`,
      type: NOTIFICATION_TYPE_COMPLAINT,
      data: { complaintId: ref.id },
    },
  ]);
  return { complaintId: ref.id };
}

export type RespondToComplaintResult = { historyId: string; status: ComplaintStatus };

/**
 * Admin: reply and/or change status. Sender: reply only (keeps the thread
 * open for follow-up; a resolved or archived complaint is reopened).
 */
export async function respondToComplaintCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<RespondToComplaintResult> {
  const uid = requireCallerUid(callerUid);
  const role = await loadCallerRole(db, uid);
  const complaintId = requireText(data.complaintId, "complaintId", 128);
  const message = optionalText(data.message, COMPLAINT_MESSAGE_MAX);
  const requested = parseComplaintStatus(data.status);
  if (message === "" && requested === null) {
    throw new HttpsError("invalid-argument", "اكتب رداً أو اختر حالة");
  }
  rejectContactInfo(message);

  const ref = db.collection(COMPLAINTS_COLLECTION).doc(complaintId);
  const authorName = await loadName(db, uid);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الشكوى غير موجودة");
    const c = snap.data() ?? {};
    const isAdmin = role === "admin";
    const isSender = c.senderId === uid && role !== "";
    if (!isAdmin && !isSender) {
      throw new HttpsError("permission-denied", "لا تملك صلاحية على هذه الشكوى");
    }
    if (!isAdmin && requested !== null) {
      throw new HttpsError("permission-denied", "تغيير الحالة متاح للإدارة فقط");
    }
    const current = (COMPLAINT_STATUSES as readonly string[]).includes(c.status)
      ? (c.status as ComplaintStatus)
      : "open";
    let next: ComplaintStatus = requested ?? current;
    if (isAdmin && requested === null && current === "open") next = "in_progress";
    if (!isAdmin && (current === "resolved" || current === "archived")) next = "open";

    const historyRef = ref.collection(COMPLAINT_HISTORY_SUBCOLLECTION).doc();
    tx.set(historyRef, {
      authorId: uid,
      authorRole: role,
      authorName,
      message,
      statusFrom: current,
      statusTo: next,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, {
      status: next,
      historyCount: FieldValue.increment(1),
      lastActivityBy: isAdmin ? "admin" : "sender",
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {
      historyId: historyRef.id,
      status: next,
      senderId: typeof c.senderId === "string" ? c.senderId : "",
      subject: typeof c.subject === "string" ? c.subject : "",
      isAdmin,
      changed: next !== current,
    };
  });

  const notification: InAppNotification = result.isAdmin
    ? {
        notificationId: `${result.senderId}_complaint_update_${result.historyId}`,
        audience: result.senderId,
        title: result.changed ? "تحديث على شكواك" : "رد على شكواك",
        body: message !== "" ? message.slice(0, 140) : `الحالة: ${statusLabel(result.status)}`,
        type: NOTIFICATION_TYPE_COMPLAINT,
        data: { complaintId },
      }
    : {
        notificationId: `admin_complaint_reply_${result.historyId}`,
        audience: "admin",
        title: "رد جديد على شكوى",
        body: `${authorName || "مستخدم"}: ${result.subject}`,
        type: NOTIFICATION_TYPE_COMPLAINT,
        data: { complaintId },
      };
  await writeInAppNotifications(db, [notification]);
  return { historyId: result.historyId, status: result.status };
}

export function statusLabel(status: ComplaintStatus): string {
  switch (status) {
    case "open":
      return "جديدة";
    case "in_progress":
      return "قيد المعالجة";
    case "resolved":
      return "تم الحل";
    case "archived":
      return "مؤرشفة";
  }
}

export const submitComplaint = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("submitComplaint");
  return submitComplaintCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const respondToComplaint = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("respondToComplaint");
  return respondToComplaintCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
