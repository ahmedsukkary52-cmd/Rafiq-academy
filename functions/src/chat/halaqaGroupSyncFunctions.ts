/**
 * WA-10 / C8 — Halaqa group membership sync entrypoints.
 *
 * - Firestore trigger: membership field changes on halaqat/{id}
 * - Admin callable: explicit ensure/sync
 *
 * Does not trust client participantIds. Production-gated (WA-0).
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertCallerIsAdmin } from "../admin/assertAdmin";
import { assertBackendAllowed } from "../productionGate";
import {
  halaqaMembershipFieldsChanged,
  type HalaqaMembershipSource,
} from "./halaqaGroupSync";
import { syncHalaqaGroupConversation } from "./syncHalaqaGroupConversation";

function asMembershipSource(
  data: Record<string, unknown> | undefined,
): HalaqaMembershipSource {
  return {
    teacherId: data?.teacherId,
    supervisorId: data?.supervisorId,
    studentIds: data?.studentIds,
    name: data?.name,
    status: data?.status,
  };
}

/**
 * On halaqa create/update: project membership into conversations/halaqa_group_*.
 * Skips when membership SSOT fields are unchanged (avoids pointer-write loops).
 * On halaqa delete: clears group participantIds but retains the conversation + messages.
 */
export const syncHalaqaGroupOnWrite = onDocumentWritten(
  {
    document: "halaqat/{halaqaId}",
    region: "europe-west1",
  },
  async (event) => {
    assertBackendAllowed("syncHalaqaGroupOnWrite");

    const halaqaId = event.params.halaqaId;
    if (typeof halaqaId !== "string" || !halaqaId.trim()) return;

    const before = event.data?.before;
    const after = event.data?.after;
    const db = admin.firestore();

    if (!after?.exists) {
      // Halaqa deleted — keep conversation/history; clear active members.
      await syncHalaqaGroupConversation({
        db,
        halaqaId,
        halaqa: { teacherId: "", supervisorId: "", studentIds: [] },
        createdBy: "system",
        writeHalaqaPointer: false,
      });
      return;
    }

    const beforeData = before?.exists
      ? (before.data() as Record<string, unknown>)
      : undefined;
    const afterData = (after.data() ?? {}) as Record<string, unknown>;
    if (
      !halaqaMembershipFieldsChanged(
        beforeData ? asMembershipSource(beforeData) : null,
        asMembershipSource(afterData),
      )
    ) {
      return;
    }

    await syncHalaqaGroupConversation({
      db,
      halaqaId,
      halaqa: asMembershipSource(afterData),
      createdBy: "system",
      writeHalaqaPointer: true,
    });
  },
);

/**
 * Admin-only explicit ensure/sync (ops / backfill).
 */
export const adminSyncHalaqaGroup = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminSyncHalaqaGroup");
    const uid = await assertCallerIsAdmin(request.auth?.uid);

    const raw = request.data?.halaqaId;
    if (typeof raw !== "string" || raw.trim().length === 0) {
      throw new HttpsError("invalid-argument", "halaqaId مطلوب");
    }
    const halaqaId = raw.trim();
    // Reject client-supplied membership arrays entirely.
    if (
      request.data?.participantIds !== undefined
      || request.data?.studentIds !== undefined
      || request.data?.teacherId !== undefined
    ) {
      throw new HttpsError(
        "invalid-argument",
        "لا يمكن تمرير أعضاء المجموعة من العميل",
      );
    }

    const db = admin.firestore();
    const snap = await db.collection("halaqat").doc(halaqaId).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "الحلقة غير موجودة");
    }

    return syncHalaqaGroupConversation({
      db,
      halaqaId,
      halaqa: asMembershipSource(snap.data() as Record<string, unknown>),
      createdBy: uid,
      writeHalaqaPointer: true,
    });
  },
);
