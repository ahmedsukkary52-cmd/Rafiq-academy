/**
 * Admin group entrypoints. Membership is projected from users/ by the
 * backend only; the client can open the group but never name its members.
 *
 * - ensureAdminGroupConversation: Admin callable, creates the group once
 *   (deterministic id + transaction) and re-syncs it on every call.
 * - syncAdminGroupOnUserWrite: keeps an existing group in step when an
 *   Admin is added, activated, deactivated, demoted or renamed. Never creates.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { loadCallerRole, requireCallerUid } from "../authority/callerContext";
import {
  assertBackendAllowed,
  isEmulatorBackendAllowed,
  isProductionBackendEnabled,
} from "../productionGate";
import {
  ADMIN_GROUP_CLIENT_FORBIDDEN_FIELDS,
  ADMIN_GROUP_CONVERSATION_ID,
  ADMIN_GROUP_KIND,
  ADMIN_GROUP_TITLE,
  adminGroupRelevantChange,
  decideAdminGroupSync,
} from "./adminGroupSync";

type Db = admin.firestore.Firestore;

export type SyncAdminGroupResult = {
  conversationId: string;
  action: "absent" | "create" | "update" | "noop";
  participantIds: string[];
  participantCount: number;
};

/** Reads every Admin profile and the group in one transaction, then writes once. */
export async function syncAdminGroupConversation(params: {
  db: Db;
  createdBy: string;
  allowCreate: boolean;
}): Promise<SyncAdminGroupResult> {
  const { db, createdBy, allowCreate } = params;
  const conversationRef = db.collection("conversations").doc(ADMIN_GROUP_CONVERSATION_ID);
  const adminsQuery = db.collection("users").where("role", "==", "admin");

  let result!: SyncAdminGroupResult;
  await db.runTransaction(async (tx) => {
    const adminsSnap = await tx.get(adminsQuery);
    const snap = await tx.get(conversationRef);
    const decision = decideAdminGroupSync({
      users: adminsSnap.docs.map((d) => ({
        uid: d.id,
        data: d.data() as Record<string, unknown> | undefined,
      })),
      existing: snap.exists ? ((snap.data() ?? {}) as Record<string, unknown>) : null,
      allowCreate,
    });

    if (decision.action === "create") {
      const unreadCounts: Record<string, number> = {};
      for (const id of decision.participantIds) unreadCounts[id] = 0;
      tx.create(conversationRef, {
        kind: ADMIN_GROUP_KIND,
        title: ADMIN_GROUP_TITLE,
        participantIds: decision.participantIds,
        participants: decision.participants,
        unreadCounts,
        lastMessage: null,
        lastMessageAt: null,
        lastMessageSenderId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        membershipSyncedAt: FieldValue.serverTimestamp(),
        createdBy,
      });
    } else if (decision.action === "update") {
      // update() replaces each top-level map, so removed members lose their
      // unread counter; lastMessage*, createdAt and createdBy are untouched.
      tx.update(conversationRef, {
        title: ADMIN_GROUP_TITLE,
        participantIds: decision.participantIds,
        participants: decision.participants,
        unreadCounts: decision.unreadCounts,
        updatedAt: FieldValue.serverTimestamp(),
        membershipSyncedAt: FieldValue.serverTimestamp(),
      });
    }
    result = {
      conversationId: ADMIN_GROUP_CONVERSATION_ID,
      action: decision.action,
      participantIds: decision.participantIds,
      participantCount: decision.participantIds.length,
    };
  });
  return result;
}

export async function ensureAdminGroupConversationCore(
  db: Db,
  callerUid: string | undefined,
  data: unknown,
): Promise<{ conversationId: string; action: string; participantCount: number }> {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "مجموعة الإدارة متاحة للمدير النشط فقط");
  }
  const payload = data && typeof data === "object" ? (data as Record<string, unknown>) : {};
  if (ADMIN_GROUP_CLIENT_FORBIDDEN_FIELDS.some((f) => payload[f] !== undefined)) {
    throw new HttpsError("invalid-argument", "لا يمكن تمرير أعضاء المجموعة من العميل");
  }

  let result: SyncAdminGroupResult;
  try {
    result = await syncAdminGroupConversation({ db, createdBy: uid, allowCreate: true });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error("[adminGroup] ensure failed", e);
    throw new HttpsError("failed-precondition", "تعذر تجهيز مجموعة الإدارة");
  }
  if (!result.participantIds.includes(uid)) {
    throw new HttpsError("permission-denied", "مجموعة الإدارة متاحة للمدير النشط فقط");
  }
  return {
    conversationId: result.conversationId,
    action: result.action,
    participantCount: result.participantCount,
  };
}

/** Returns the sync action, or null when the write cannot affect the group. */
export async function handleAdminGroupUserWrite(
  db: Db,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): Promise<SyncAdminGroupResult["action"] | null> {
  if (!adminGroupRelevantChange(before, after)) return null;
  const result = await syncAdminGroupConversation({ db, createdBy: "system", allowCreate: false });
  return result.action;
}

export const ensureAdminGroupConversation = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("ensureAdminGroupConversation");
    return ensureAdminGroupConversationCore(admin.firestore(), request.auth?.uid, request.data);
  },
);

export const syncAdminGroupOnUserWrite = onDocumentWritten(
  {
    document: "users/{uid}",
    region: "europe-west1",
  },
  async (event) => {
    if (!isProductionBackendEnabled() && !isEmulatorBackendAllowed()) {
      console.warn("[adminGroup] syncAdminGroupOnUserWrite skipped — backend gate closed");
      return;
    }
    const before = event.data?.before;
    const after = event.data?.after;
    try {
      await handleAdminGroupUserWrite(
        admin.firestore(),
        before?.exists ? (before.data() as Record<string, unknown>) : undefined,
        after?.exists ? (after.data() as Record<string, unknown>) : undefined,
      );
    } catch (e) {
      console.error("[adminGroup] membership sync failed", e);
    }
  },
);
