/**
 * WA-11 — server-authoritative 1:1 conversation create + message soft-delete/edit.
 */

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBackendAllowed } from "../productionGate";
import {
  canEditMessage,
  canSoftDeleteMessage,
  DIRECT_CHAT_KIND,
  directConversationId,
  isChatRole,
  isDirectChatRelationshipAllowed,
  softDeletePayload,
  type ChatRole,
} from "./chatRelationship";
import {
  loadParticipantProfile,
  loadRelationshipContext,
  loadUserRole,
} from "./loadChatRelationships";
import { isHalaqaGroupConversationId } from "./halaqaGroupSync";
import {
  CHAT_DELETED_PREVIEW,
  ChatInputError,
  messagePreview,
  normalizeMessageText,
} from "./chatMessageContract";

function requireUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }
  return uid;
}

function requireOtherUid(raw: unknown): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", "otherUid مطلوب");
  }
  return raw.trim();
}

async function assertDirectRelationship(
  db: admin.firestore.Firestore,
  callerUid: string,
  otherUid: string,
): Promise<{ roleA: ChatRole; roleB: ChatRole }> {
  if (callerUid === otherUid) {
    throw new HttpsError("invalid-argument", "لا يمكن إنشاء محادثة مع نفسك");
  }
  const roleA = await loadUserRole(db, callerUid);
  const roleB = await loadUserRole(db, otherUid);
  if (!roleA || !roleB) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }
  const ctxA = await loadRelationshipContext(db, callerUid, roleA);
  const ctxB = await loadRelationshipContext(db, otherUid, roleB);
  const ok = isDirectChatRelationshipAllowed({
    roleA,
    uidA: callerUid,
    roleB,
    uidB: otherUid,
    ctxA,
    ctxB,
  });
  if (!ok) {
    throw new HttpsError(
      "permission-denied",
      "غير مسموح بإنشاء محادثة — لا توجد علاقة معتمدة بين الحسابين",
    );
  }
  return { roleA, roleB };
}

/**
 * Create-or-return deterministic 1:1 conversation after D14 graph check.
 * Rejects client-supplied participantIds arrays.
 */
export const createDirectConversation = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("createDirectConversation");
    return createDirectConversationCore(
      admin.firestore(),
      requireUid(request.auth?.uid),
      request.data,
    );
  },
);

export async function createDirectConversationCore(
  db: admin.firestore.Firestore,
  callerUid: string,
  rawData: unknown,
) {
    const data = (rawData ?? {}) as Record<string, unknown>;
    const otherUid = requireOtherUid(data.otherUid);

    if (data.participantIds !== undefined || data.participants !== undefined) {
      throw new HttpsError(
        "invalid-argument",
        "لا يمكن تمرير participantIds من العميل",
      );
    }

    await assertDirectRelationship(db, callerUid, otherUid);

    const conversationId = directConversationId(callerUid, otherUid);
    if (isHalaqaGroupConversationId(conversationId)) {
      throw new HttpsError("internal", "معرف المحادثة غير صالح");
    }

    const ref = db.collection("conversations").doc(conversationId);
    const existing = await ref.get();
    if (existing.exists) {
      const data = existing.data() ?? {};
      if (data.kind === "halaqa_group") {
        throw new HttpsError("failed-precondition", "معرف محجوز لمجموعة حلقة");
      }
      return {
        conversationId,
        created: false,
        participantIds: data.participantIds ?? [callerUid, otherUid],
      };
    }

    const [profileA, profileB] = await Promise.all([
      loadParticipantProfile(db, callerUid),
      loadParticipantProfile(db, otherUid),
    ]);

    await ref.set({
      kind: DIRECT_CHAT_KIND,
      participantIds: [callerUid, otherUid].sort(),
      participants: [profileA, profileB],
      lastMessage: null,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageSenderId: null,
      unreadCounts: { [callerUid]: 0, [otherUid]: 0 },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: callerUid,
    });

    return {
      conversationId,
      created: true,
      participantIds: [callerUid, otherUid].sort(),
    };
}

/**
 * Soft-delete a message (C9). Admin may moderate-delete; sender may delete own.
 */
export const softDeleteChatMessage = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("softDeleteChatMessage");
    return softDeleteChatMessageCore(
      admin.firestore(),
      requireUid(request.auth?.uid),
      request.data,
    );
  },
);

export async function softDeleteChatMessageCore(
  db: admin.firestore.Firestore,
  callerUid: string,
  rawData: unknown,
) {
    const data = (rawData ?? {}) as Record<string, unknown>;
    const conversationId = requireOtherUid(data.conversationId);
    const messageId = requireOtherUid(data.messageId);

    const role = await loadUserRole(db, callerUid);
    if (!role) {
      throw new HttpsError("permission-denied", "ملف المستخدم غير موجود");
    }

    const convRef = db.collection("conversations").doc(conversationId);
    const msgRef = convRef.collection("messages").doc(messageId);

    await db.runTransaction(async (tx) => {
      const convSnap = await tx.get(convRef);
      if (!convSnap.exists) {
        throw new HttpsError("not-found", "المحادثة غير موجودة");
      }
      const participantIds = Array.isArray(convSnap.data()?.participantIds)
        ? (convSnap.data()!.participantIds as unknown[])
            .filter((x): x is string => typeof x === "string")
        : [];
      const isParticipant = participantIds.includes(callerUid);
      if (!isParticipant && role !== "admin") {
        throw new HttpsError("permission-denied", "لست مشاركاً في المحادثة");
      }

      const msgSnap = await tx.get(msgRef);
      if (!msgSnap.exists) {
        throw new HttpsError("not-found", "الرسالة غير موجودة");
      }
      const msg = msgSnap.data() ?? {};
      const senderId =
        typeof msg.senderId === "string" ? msg.senderId : "";
      const alreadyDeleted = msg.deleted === true;
      const sentAt = msg.sentAt instanceof Timestamp
        ? msg.sentAt.toDate()
        : new Date(0);
      if (
        !canSoftDeleteMessage({
          senderId,
          callerUid,
          callerRole: role,
          alreadyDeleted,
          sentAt,
        })
      ) {
        throw new HttpsError(
          "permission-denied",
          "غير مسموح بحذف هذه الرسالة",
        );
      }

      // Media metadata leaves the client-readable doc; the Storage object is
      // retained (Admin-readable only) until a retention policy (D20) exists.
      const payload = softDeletePayload({ deletedBy: callerUid });
      tx.update(msgRef, {
        deleted: true,
        deletedAt: FieldValue.serverTimestamp(),
        deletedBy: payload.deletedBy,
        text: "",
        media: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (convSnap.data()?.lastMessageId === messageId) {
        tx.update(convRef, {
          lastMessage: CHAT_DELETED_PREVIEW,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });

    return { conversationId, messageId, deleted: true };
}

/**
 * Edit own message within the C9 time window.
 */
export async function editChatMessageCore(
  db: admin.firestore.Firestore,
  callerUid: string,
  rawData: unknown,
) {
  const data = (rawData ?? {}) as Record<string, unknown>;
  const conversationId = requireOtherUid(data.conversationId);
  const messageId = requireOtherUid(data.messageId);
  let text: string;
  try {
    text = normalizeMessageText(data.text);
  } catch (e) {
    if (e instanceof ChatInputError) throw new HttpsError(e.code, e.message);
    throw e;
  }
  if (text.length === 0) {
    throw new HttpsError("invalid-argument", "نص الرسالة مطلوب");
  }

  const role = await loadUserRole(db, callerUid);
  if (!role) {
    throw new HttpsError("permission-denied", "الحساب غير مفعّل");
  }
  const convRef = db.collection("conversations").doc(conversationId);
  const msgRef = convRef.collection("messages").doc(messageId);

  await db.runTransaction(async (tx) => {
    const convSnap = await tx.get(convRef);
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "المحادثة غير موجودة");
    }
    const participantIds = Array.isArray(convSnap.data()?.participantIds)
      ? (convSnap.data()!.participantIds as unknown[])
          .filter((x): x is string => typeof x === "string")
      : [];
    if (!participantIds.includes(callerUid)) {
      throw new HttpsError("permission-denied", "لست مشاركاً في المحادثة");
    }

    const msgSnap = await tx.get(msgRef);
    if (!msgSnap.exists) {
      throw new HttpsError("not-found", "الرسالة غير موجودة");
    }
    const msg = msgSnap.data() ?? {};
    const senderId =
      typeof msg.senderId === "string" ? msg.senderId : "";
    const sentAtRaw = msg.sentAt;
    const sentAt =
      sentAtRaw instanceof Timestamp
        ? sentAtRaw.toDate()
        : sentAtRaw instanceof Date
          ? sentAtRaw
          : new Date(0);
    if (
      !canEditMessage({
        senderId,
        callerUid,
        sentAt,
        alreadyDeleted: msg.deleted === true,
      })
    ) {
      throw new HttpsError(
        "permission-denied",
        "غير مسموح بتعديل هذه الرسالة",
      );
    }
    if ((msg.type ?? "text") !== "text") {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن تعديل رسائل الوسائط",
      );
    }

    tx.update(msgRef, {
      text,
      editedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (convSnap.data()?.lastMessageId === messageId) {
      tx.update(convRef, {
        lastMessage: messagePreview("text", text),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { conversationId, messageId, edited: true };
}

export const editChatMessage = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("editChatMessage");
    const callerUid = requireUid(request.auth?.uid);
    return editChatMessageCore(admin.firestore(), callerUid, request.data);
  },
);

/** Exported for tests — relationship assertion without callable wrapper. */
export async function assertDirectChatAllowedForTest(
  db: admin.firestore.Firestore,
  callerUid: string,
  otherUid: string,
): Promise<boolean> {
  const roleA = await loadUserRole(db, callerUid);
  const roleB = await loadUserRole(db, otherUid);
  if (!roleA || !roleB || !isChatRole(roleA) || !isChatRole(roleB)) {
    return false;
  }
  const ctxA = await loadRelationshipContext(db, callerUid, roleA);
  const ctxB = await loadRelationshipContext(db, otherUid, roleB);
  return isDirectChatRelationshipAllowed({
    roleA,
    uidA: callerUid,
    roleB,
    uidB: otherUid,
    ctxA,
    ctxB,
  });
}
