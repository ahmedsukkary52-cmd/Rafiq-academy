/**
 * Payment lifecycle → in-app notifications (external payments: parent
 * uploads proof → supervisor reviews → Admin sees the verified record).
 *
 * Fired on every `payments/{id}` update; only real transitions notify:
 *   • reviewStatus → pending_review : the student's halaqa supervisor(s)
 *   • reviewStatus → approved / partial / rejected : the parent; Admin
 *     (role audience) when the payment became fully paid
 *   • status → overdue : the parent
 * Ids are deterministic per proof cycle so retries never duplicate.
 */

import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

import type { InAppNotification } from "./academyNotifications";
import { loadStudentNames, writeInAppNotifications } from "./academyNotificationStore";
import { pushGateBlockedMessage, resolvePushSendMode } from "./pushGate";

export const NOTIFICATION_TYPE_PAYMENT = "payment";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function cycleKey(data: Record<string, unknown>): string {
  const cycle = text(data.proofCycleId);
  if (cycle) return cycle;
  const at = data.proofSubmittedAt as { toMillis?: () => number } | undefined;
  return typeof at?.toMillis === "function" ? String(at.toMillis()) : "initial";
}

function money(raw: unknown): string {
  return typeof raw === "number" && Number.isFinite(raw) ? `${raw} جنيه` : "";
}

export async function paymentTransitionNotifications(
  db: admin.firestore.Firestore,
  paymentId: string,
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Promise<InAppNotification[]> {
  const parentId = text(after.parentId);
  const studentId = text(after.studentId);
  const cycle = cycleKey(after);
  const reviewBefore = text(before.reviewStatus);
  const reviewAfter = text(after.reviewStatus);
  const statusBefore = text(before.status);
  const statusAfter = text(after.status);
  const data = { paymentId, ...(studentId ? { studentId } : {}) };
  const out: InAppNotification[] = [];

  const studentName = studentId
    ? (await loadStudentNames(db, [studentId])).get(studentId) ?? "الطالب"
    : "الطالب";

  if (reviewAfter === "pending_review" && reviewBefore !== "pending_review" && studentId) {
    const halaqat = await db
      .collection("halaqat")
      .where("studentIds", "array-contains", studentId)
      .limit(5)
      .get();
    const supervisors = [
      ...new Set(halaqat.docs.map((d) => text(d.get("supervisorId"))).filter(Boolean)),
    ];
    for (const uid of supervisors) {
      out.push({
        notificationId: `${uid}_payment_proof_${paymentId}_${cycle}`,
        audience: uid,
        title: "إيصال دفع بانتظار المراجعة",
        body: `رفع ولي أمر ${studentName} إيصال دفع ${money(after.amount)}`.trim(),
        type: NOTIFICATION_TYPE_PAYMENT,
        data,
      });
    }
  }

  const decided = ["approved", "partial", "rejected"];
  if (decided.includes(reviewAfter) && reviewAfter !== reviewBefore && parentId) {
    const title =
      reviewAfter === "approved"
        ? "تم اعتماد الدفعة"
        : reviewAfter === "partial"
          ? "تم اعتماد دفعة جزئية"
          : "تم رفض إيصال الدفع";
    const body =
      reviewAfter === "partial"
        ? `المتبقي: ${money(after.remainingAmount)}`
        : reviewAfter === "rejected"
          ? "يرجى مراجعة الإيصال ورفعه مرة أخرى"
          : `دفعة ${studentName} ${money(after.amount)}`.trim();
    out.push({
      notificationId: `${parentId}_payment_review_${paymentId}_${cycle}`,
      audience: parentId,
      title,
      body,
      type: NOTIFICATION_TYPE_PAYMENT,
      data,
    });
  }

  if (statusAfter === "paid" && statusBefore !== "paid") {
    out.push({
      notificationId: `admin_payment_paid_${paymentId}`,
      audience: "admin",
      title: "دفعة موثّقة",
      body: `تم التحقق من دفعة ${studentName} ${money(after.amount)}`.trim(),
      type: NOTIFICATION_TYPE_PAYMENT,
      data,
    });
  }

  if (statusAfter === "overdue" && statusBefore !== "overdue" && parentId) {
    out.push({
      notificationId: `${parentId}_payment_overdue_${paymentId}`,
      audience: parentId,
      title: "دفعة متأخرة",
      body: `دفعة ${studentName} ${money(after.amount)} متأخرة عن موعدها`.trim(),
      type: NOTIFICATION_TYPE_PAYMENT,
      data,
    });
  }
  return out;
}

export const notifyOnPaymentUpdated = onDocumentUpdated(
  { region: "europe-west1", document: "payments/{paymentId}" },
  async (event) => {
    if (resolvePushSendMode() === "blocked") {
      console.warn(pushGateBlockedMessage("notifyOnPaymentUpdated"));
      return;
    }
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const db = admin.firestore();
    const list = await paymentTransitionNotifications(db, event.params.paymentId, before, after);
    if (list.length > 0) await writeInAppNotifications(db, list);
  },
);