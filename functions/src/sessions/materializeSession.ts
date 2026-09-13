/**
 * WA-8 / C6 — materialize first-class Session occurrence.
 *
 * Idempotent + concurrent-safe via deterministic doc id + Firestore transaction.
 * Snapshots occurrence fields at create; never rewrites existing identity.
 */

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { normalizeCairoYmd } from "../billing/cairoTime";
import { assertBackendAllowed } from "../productionGate";
import {
  canCallerMaterialize,
  decideMaterialize,
  deterministicSessionId,
  type ExistingSessionDoc,
} from "../sessions/sessionMaterialization";

interface MaterializeRequest {
  halaqaId?: unknown;
  slotId?: unknown;
  /** Cairo calendar date YYYY-MM-DD */
  date?: unknown;
  /** Ignored if present — teacher/supervisor come from halaqa only. */
  teacherId?: unknown;
  supervisorId?: unknown;
}

function requireString(raw: unknown, field: string): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} مطلوب`);
  }
  return raw.trim();
}

function requireCairoDate(raw: unknown): string {
  try {
    return normalizeCairoYmd(requireString(raw, "date"));
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "date يجب أن يكون تاريخ القاهرة بصيغة YYYY-MM-DD",
    );
  }
}

async function assertCanMaterialize(params: {
  uid: string;
  teacherId: string;
}): Promise<{ role: string; createdBy: string }> {
  const snap = await admin.firestore().collection("users").doc(params.uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "ملف المستخدم غير موجود");
  }
  const role = snap.data()?.role;
  if (
    !canCallerMaterialize({
      callerUid: params.uid,
      callerRole: role,
      halaqaTeacherId: params.teacherId,
    })
  ) {
    throw new HttpsError(
      "permission-denied",
      "إنشاء الجلسة متاح للمسؤول أو معلّم الحلقة فقط",
    );
  }
  return {
    role: typeof role === "string" ? role : "",
    createdBy: params.uid,
  };
}

function mapMaterializeError(err: unknown): never {
  if (err instanceof HttpsError) throw err;
  const message = err instanceof Error ? err.message : String(err);
  if (message.includes("slotId is required")) {
    throw new HttpsError("invalid-argument", "slotId مطلوب (WA-7)");
  }
  if (
    message.includes("schedule is missing") ||
    message.includes("schedule is empty") ||
    message.includes("malformed")
  ) {
    throw new HttpsError("failed-precondition", "جدول الحلقة غير صالح");
  }
  if (message.includes("slot not found")) {
    throw new HttpsError("not-found", "slotId غير موجود في جدول الحلقة");
  }
  if (message.includes("weekday does not match")) {
    throw new HttpsError(
      "invalid-argument",
      "تاريخ القاهرة لا يطابق يوم الموعد في الجدول",
    );
  }
  if (
    message.includes("times are invalid") ||
    message.includes("endAt must be after")
  ) {
    throw new HttpsError("failed-precondition", "أوقات الموعد غير صالحة");
  }
  if (message.includes("teacherId is required")) {
    throw new HttpsError("failed-precondition", "الحلقة بلا معلّم");
  }
  if (message.includes("duplicate slotId")) {
    throw new HttpsError("failed-precondition", "slotId مكرر في الجدول");
  }
  if (message.includes("day label is invalid")) {
    throw new HttpsError("failed-precondition", "يوم الموعد غير صالح");
  }
  throw new HttpsError("internal", message);
}

/**
 * WA-8 — Create-or-reuse `sessions/{sessionId}` for one slot occurrence.
 * Gated by WA-0 production backend gate.
 */
export const materializeSession = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("materializeSession");

    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }

    const data = (request.data ?? {}) as MaterializeRequest;
    const halaqaId = requireString(data.halaqaId, "halaqaId");
    // Missing slotId must fail — never invent a replacement (WA-7 owns ids).
    const slotId = requireString(data.slotId, "slotId");
    const date = requireCairoDate(data.date);

    const db = admin.firestore();
    const halaqaRef = db.collection("halaqat").doc(halaqaId);
    const halaqaSnap = await halaqaRef.get();
    if (!halaqaSnap.exists) {
      throw new HttpsError("not-found", "الحلقة غير موجودة");
    }

    const halaqaRaw = halaqaSnap.data() ?? {};
    const teacherId =
      typeof halaqaRaw.teacherId === "string" ? halaqaRaw.teacherId.trim() : "";
    if (!teacherId) {
      throw new HttpsError("failed-precondition", "الحلقة بلا معلّم");
    }

    const authz = await assertCanMaterialize({ uid, teacherId });

    const identity = { halaqaId, slotId, date };
    const sessionId = deterministicSessionId(identity);
    const sessionRef = db.collection("sessions").doc(sessionId);

    type TxResult = {
      sessionId: string;
      created: boolean;
      halaqaId: string;
      slotId: string;
      date: string;
      status: string;
      teacherId: string;
      supervisorId: string | null;
      startAtMs: number;
      endAtMs: number;
      createdBy: string;
    };

    let result: TxResult;

    try {
      result = await db.runTransaction(async (tx) => {
        const existingSnap = await tx.get(sessionRef);
        const existing = existingSnap.exists
          ? (existingSnap.data() as ExistingSessionDoc)
          : null;

        const decision = decideMaterialize({
          identity,
          existing,
          halaqa: {
            teacherId: halaqaRaw.teacherId,
            supervisorId: halaqaRaw.supervisorId,
            schedule: halaqaRaw.schedule,
          },
        });

        if (decision.action === "reuse") {
          const ex = decision.existing;
          const startAt =
            ex.startAt instanceof Timestamp
              ? ex.startAt.toDate()
              : ex.startAt instanceof Date
                ? ex.startAt
                : null;
          const endAt =
            ex.endAt instanceof Timestamp
              ? ex.endAt.toDate()
              : ex.endAt instanceof Date
                ? ex.endAt
                : null;
          return {
            sessionId: decision.sessionId,
            created: false,
            halaqaId: String(ex.halaqaId ?? halaqaId),
            slotId: String(ex.slotId ?? slotId),
            date: String(ex.date ?? date),
            status: String(ex.status ?? "scheduled"),
            teacherId: String(ex.teacherId ?? teacherId),
            supervisorId:
              typeof ex.supervisorId === "string" && ex.supervisorId.trim()
                ? ex.supervisorId.trim()
                : null,
            startAtMs: startAt?.getTime() ?? 0,
            endAtMs: endAt?.getTime() ?? 0,
            createdBy: String(ex.createdBy ?? ""),
          };
        }

        const fields = decision.fields;
        const createPayload: Record<string, unknown> = {
          halaqaId: fields.halaqaId,
          slotId: fields.slotId,
          date: fields.date,
          startAt: Timestamp.fromDate(fields.startAt),
          endAt: Timestamp.fromDate(fields.endAt),
          status: fields.status,
          teacherId: fields.teacherId,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          createdBy: authz.createdBy,
        };
        if (fields.supervisorId) {
          createPayload.supervisorId = fields.supervisorId;
        }

        // set() + transaction retry: concurrent creators converge on one doc.
        tx.set(sessionRef, createPayload);

        return {
          sessionId: decision.sessionId,
          created: true,
          halaqaId: fields.halaqaId,
          slotId: fields.slotId,
          date: fields.date,
          status: fields.status,
          teacherId: fields.teacherId,
          supervisorId: fields.supervisorId ?? null,
          startAtMs: fields.startAt.getTime(),
          endAtMs: fields.endAt.getTime(),
          createdBy: authz.createdBy,
        };
      });
    } catch (err) {
      mapMaterializeError(err);
    }

    return result!;
  },
);
