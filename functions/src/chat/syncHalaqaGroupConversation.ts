/**
 * WA-10 / C8 — apply Halaqa group membership projection to conversations/.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import {
  decideHalaqaGroupSync,
  HALAQA_GROUP_KIND,
  halaqaGroupConversationId,
  type HalaqaMembershipSource,
} from "./halaqaGroupSync";

export type SyncHalaqaGroupResult = {
  conversationId: string;
  halaqaId: string;
  action: "create" | "update" | "noop";
  participantIds: string[];
  participantCount: number;
};

/**
 * Transactional ensure/sync of conversations/halaqa_group_{halaqaId}.
 * Preserves lastMessage* and createdAt; replaces participantIds projection.
 */
export async function syncHalaqaGroupConversation(params: {
  db: admin.firestore.Firestore;
  halaqaId: string;
  halaqa: HalaqaMembershipSource;
  createdBy: string;
  /** When true, also set halaqat.groupConversationId if missing/mismatched. */
  writeHalaqaPointer?: boolean;
}): Promise<SyncHalaqaGroupResult> {
  const { db, halaqaId, halaqa, createdBy } = params;
  const conversationId = halaqaGroupConversationId(halaqaId);
  const conversationRef = db.collection("conversations").doc(conversationId);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);

  let result!: SyncHalaqaGroupResult;

  await db.runTransaction(async (tx) => {
    // All reads before writes (Firestore transaction rule).
    const snap = await tx.get(conversationRef);
    const halaqaSnap = params.writeHalaqaPointer
      ? await tx.get(halaqaRef)
      : null;

    const existing = snap.exists ? (snap.data() ?? {}) : null;
    const decision = decideHalaqaGroupSync({
      halaqaId,
      halaqa,
      existing,
    });

    if (decision.action === "noop") {
      result = {
        conversationId,
        halaqaId,
        action: "noop",
        participantIds: decision.participantIds,
        participantCount: decision.participantIds.length,
      };
    } else if (decision.action === "create") {
      const unreadCounts: Record<string, number> = {};
      for (const id of decision.participantIds) unreadCounts[id] = 0;
      tx.set(conversationRef, {
        kind: HALAQA_GROUP_KIND,
        halaqaId: decision.halaqaId,
        title: decision.title,
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
      result = {
        conversationId,
        halaqaId,
        action: "create",
        participantIds: decision.participantIds,
        participantCount: decision.participantIds.length,
      };
    } else {
      const update: Record<string, unknown> = {
        kind: HALAQA_GROUP_KIND,
        halaqaId: decision.halaqaId,
        title: decision.title,
        participantIds: decision.participantIds,
        participants: decision.participants,
        unreadCounts: decision.preserve.unreadCounts,
        updatedAt: FieldValue.serverTimestamp(),
        membershipSyncedAt: FieldValue.serverTimestamp(),
      };
      if (decision.preserve.createdAt !== undefined) {
        update.createdAt = decision.preserve.createdAt;
      }
      if (decision.preserve.createdBy !== undefined) {
        update.createdBy = decision.preserve.createdBy;
      }
      if (decision.preserve.lastMessage !== undefined) {
        update.lastMessage = decision.preserve.lastMessage;
      }
      if (decision.preserve.lastMessageAt !== undefined) {
        update.lastMessageAt = decision.preserve.lastMessageAt;
      }
      if (decision.preserve.lastMessageSenderId !== undefined) {
        update.lastMessageSenderId = decision.preserve.lastMessageSenderId;
      }
      tx.set(conversationRef, update, { merge: true });
      result = {
        conversationId,
        halaqaId,
        action: "update",
        participantIds: decision.participantIds,
        participantCount: decision.participantIds.length,
      };
    }

    if (params.writeHalaqaPointer && halaqaSnap?.exists) {
      const current = halaqaSnap.data()?.groupConversationId;
      if (current !== conversationId) {
        tx.update(halaqaRef, {
          groupConversationId: conversationId,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });

  return result;
}
