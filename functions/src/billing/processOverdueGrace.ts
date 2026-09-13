import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  isEmulatorBackendAllowed,
  isProductionBackendEnabled,
} from "../productionGate";
import {
  isValidPaymentAccessStatus,
  PaymentAccessStatus,
} from "./paymentHelpers";
import {
  computeParentAccessTarget,
  paymentMutationsForUnpaid,
  resolveAccessTransition,
  UnpaidInvoiceLike,
} from "./overdueGraceLogic";

const DEFAULT_GRACE_DAYS = 7;

type PassStats = {
  parentsProcessed: number;
  paymentsMarkedOverdue: number;
  accessUpserts: number;
  skippedSuspendedLocked: number;
};

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

async function loadGracePeriodDays(
  db: admin.firestore.Firestore,
): Promise<number> {
  const snap = await db
    .collection("academySettings")
    .doc("pricingDefaults")
    .get();
  const raw = snap.data()?.gracePeriodDays;
  if (typeof raw === "number" && Number.isFinite(raw) && raw >= 0) {
    return Math.floor(raw);
  }
  return DEFAULT_GRACE_DAYS;
}

async function loadChildrenIds(
  db: admin.firestore.Firestore,
  parentId: string,
): Promise<string[]> {
  const snap = await db.collection("parentProfiles").doc(parentId).get();
  const raw = snap.data()?.childrenIds;
  if (!Array.isArray(raw)) return [];
  return raw.map((id) => String(id)).filter((id) => id.length > 0);
}

function groupUnpaidByParent(
  docs: admin.firestore.QueryDocumentSnapshot[],
): Map<string, UnpaidInvoiceLike[]> {
  const map = new Map<string, UnpaidInvoiceLike[]>();
  for (const doc of docs) {
    const data = doc.data();
    const parentId = String(data.parentId ?? "").trim();
    const dueDate = toDate(data.dueDate);
    if (!parentId || !dueDate) continue;
    const status = String(data.status ?? "");
    if (status !== "due" && status !== "overdue") continue;
    const list = map.get(parentId) ?? [];
    list.push({
      id: doc.id,
      studentId: String(data.studentId ?? ""),
      parentId,
      dueDate,
      status,
    });
    map.set(parentId, list);
  }
  return map;
}

async function applyPaymentOverdue(
  db: admin.firestore.Firestore,
  paymentId: string,
): Promise<boolean> {
  const ref = db.collection("payments").doc(paymentId);
  const snap = await ref.get();
  if (!snap.exists) return false;
  const status = String(snap.data()?.status ?? "");
  if (status !== "due") return false;
  await ref.update({
    status: "overdue",
    overdueAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return true;
}

async function upsertPaymentAccess(params: {
  db: admin.firestore.Firestore;
  parentId: string;
  currentStatus: PaymentAccessStatus | null;
  existingData: admin.firestore.DocumentData | undefined;
  target: ReturnType<typeof resolveAccessTransition>;
}): Promise<void> {
  const { db, parentId, currentStatus, existingData, target } = params;
  const ref = db.collection("paymentAccess").doc(parentId);
  const patch: Record<string, unknown> = {
    parentId,
    status: target.status,
    reason: target.reason,
    primaryInvoiceId: target.primaryInvoiceId,
    affectedStudentIds: target.affectedStudentIds,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (target.graceEndsAt) {
    patch.graceEndsAt = Timestamp.fromDate(target.graceEndsAt);
  }

  if (target.setSuspendedAt && currentStatus !== "suspended") {
    patch.suspendedAt = FieldValue.serverTimestamp();
  }
  if (target.setWarningIssuedAt && !existingData?.warningIssuedAt) {
    patch.warningIssuedAt = FieldValue.serverTimestamp();
  }
  if (target.setLastReminderAt && !existingData?.lastReminderAt) {
    patch.lastReminderAt = FieldValue.serverTimestamp();
  }

  await ref.set(patch, { merge: true });
}

function sameStringArray(a: unknown[], b: string[]): boolean {
  const left = a.map((x) => String(x)).sort();
  const right = [...b].sort();
  if (left.length !== right.length) return false;
  return left.every((v, i) => v === right[i]);
}

/**
 * One idempotent pass: mark overdue payments + update paymentAccess from
 * dueDate + gracePeriodDays (Cairo days). Never auto-reinstates after due/grace.
 */
export async function runOverdueGracePass(
  db: admin.firestore.Firestore,
  now: Date = new Date(),
): Promise<PassStats> {
  const stats: PassStats = {
    parentsProcessed: 0,
    paymentsMarkedOverdue: 0,
    accessUpserts: 0,
    skippedSuspendedLocked: 0,
  };

  const gracePeriodDays = await loadGracePeriodDays(db);
  const unpaidSnap = await db
    .collection("payments")
    .where("status", "in", ["due", "overdue"])
    .get();

  const byParent = groupUnpaidByParent(unpaidSnap.docs);

  // Also process parents who are suspended with no unpaid (keep locked).
  const suspendedSnap = await db
    .collection("paymentAccess")
    .where("status", "==", "suspended")
    .get();
  for (const doc of suspendedSnap.docs) {
    if (!byParent.has(doc.id)) {
      byParent.set(doc.id, []);
    }
  }

  for (const [parentId, unpaid] of byParent) {
    stats.parentsProcessed += 1;

    for (const mut of paymentMutationsForUnpaid(unpaid, now)) {
      if (await applyPaymentOverdue(db, mut.paymentId)) {
        stats.paymentsMarkedOverdue += 1;
      }
    }

    const childrenIds = await loadChildrenIds(db, parentId);
    const accessRef = db.collection("paymentAccess").doc(parentId);
    const accessSnap = await accessRef.get();
    const rawStatus = accessSnap.data()?.status;
    const currentStatus =
      typeof rawStatus === "string" && isValidPaymentAccessStatus(rawStatus)
        ? rawStatus
        : null;

    const computed = computeParentAccessTarget({
      unpaid,
      childrenIds,
      gracePeriodDays,
      now,
    });
    const target = resolveAccessTransition({ currentStatus, target: computed });

    if (currentStatus === "suspended" && computed.status === "ok") {
      stats.skippedSuspendedLocked += 1;
    }

    const existing = accessSnap.data();
    const sameAffected = sameStringArray(
      (existing?.affectedStudentIds as unknown[]) ?? [],
      target.affectedStudentIds,
    );
    const unchanged =
      accessSnap.exists &&
      currentStatus === target.status &&
      String(existing?.primaryInvoiceId ?? "") ===
        String(target.primaryInvoiceId ?? "") &&
      sameAffected;

    // Idempotent re-run: no transition and no field catch-up → skip write
    // (avoids rewriting updatedAt / timestamps every day).
    if (unchanged) {
      continue;
    }

    await upsertPaymentAccess({
      db,
      parentId,
      currentStatus,
      existingData: existing,
      target,
    });
    stats.accessUpserts += 1;
  }

  return stats;
}

/**
 * WA-6 — Daily Cairo-time overdue/grace job.
 * Skips when B-BILLING gate blocks production (no deploy activation).
 */
export const processPaymentOverdueGrace = onSchedule(
  {
    schedule: "every day 01:15",
    timeZone: "Africa/Cairo",
    region: "us-central1",
  },
  async () => {
    if (!isProductionBackendEnabled() && !isEmulatorBackendAllowed()) {
      console.warn(
        "[WA-6] processPaymentOverdueGrace skipped — B-BILLING gate " +
          "(set FUNCTIONS_EMULATOR or PRODUCTION_BACKEND_ENABLED after Verified)",
      );
      return;
    }
    const stats = await runOverdueGracePass(admin.firestore(), new Date());
    console.info("[WA-6] processPaymentOverdueGrace complete", stats);
  },
);
