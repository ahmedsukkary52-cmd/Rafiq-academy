/**
 * Server-authoritative chat message send (text / image / voice / file).
 *
 * Clients cannot create message documents (firestore.rules). Identity,
 * timestamps, conversation preview and unread counters are written here.
 * Media must already exist in Storage under the message's own path, uploaded
 * by the caller, within the type policy (size, MIME, file signature).
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBackendAllowed } from "../productionGate";
import {
  CHAT_SIGNATURE_HEAD_BYTES,
  ChatInputError,
  messagePreview,
  parseSendChatMessageInput,
  validateStoredMedia,
  type ParsedSendInput,
} from "./chatMessageContract";
import { loadUserRole } from "./loadChatRelationships";

type Bucket = ReturnType<ReturnType<typeof admin.storage>["bucket"]>;

export type SendChatMessageResult = {
  conversationId: string;
  messageId: string;
  created: boolean;
};

function participantIdsOf(data: admin.firestore.DocumentData | undefined): string[] {
  const raw = data?.participantIds;
  return Array.isArray(raw)
    ? raw.filter((x): x is string => typeof x === "string")
    : [];
}

async function verifyStoredMedia(
  bucket: Bucket,
  callerUid: string,
  input: ParsedSendInput,
): Promise<{ contentType: string; sizeBytes: number }> {
  if (input.type === "text" || !input.media) {
    throw new HttpsError("internal", "media expected");
  }
  const file = bucket.file(input.media.storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpsError(
      "failed-precondition",
      "لم يكتمل رفع الملف. أعد المحاولة.",
    );
  }
  const [metadata] = await file.getMetadata();
  const sizeBytes = Number(metadata.size ?? 0);
  const contentType = String(metadata.contentType ?? "");
  const custom = (metadata.metadata ?? {}) as Record<string, unknown>;
  const uploaderId =
    typeof custom.uploaderId === "string" ? custom.uploaderId : undefined;

  const [headBuffer] = await file.download({
    start: 0,
    end: CHAT_SIGNATURE_HEAD_BYTES - 1,
  });

  const problem = validateStoredMedia({
    type: input.type,
    callerUid,
    sizeBytes,
    contentType,
    uploaderId,
    head: new Uint8Array(headBuffer),
  });
  if (problem) {
    throw new HttpsError("failed-precondition", problem);
  }
  return {
    contentType: contentType.split(";")[0].trim().toLowerCase(),
    sizeBytes,
  };
}

export async function sendChatMessageCore(
  deps: { db: admin.firestore.Firestore; bucket: Bucket },
  callerUid: string,
  rawData: unknown,
): Promise<SendChatMessageResult> {
  const { db, bucket } = deps;

  let input: ParsedSendInput;
  try {
    input = parseSendChatMessageInput(rawData);
  } catch (e) {
    if (e instanceof ChatInputError) throw new HttpsError(e.code, e.message);
    throw e;
  }

  const role = await loadUserRole(db, callerUid);
  if (!role) {
    throw new HttpsError("permission-denied", "الحساب غير مفعّل");
  }

  const convRef = db.collection("conversations").doc(input.conversationId);
  const msgRef = convRef.collection("messages").doc(input.messageId);

  const preSnap = await convRef.get();
  if (!preSnap.exists) {
    throw new HttpsError("not-found", "المحادثة غير موجودة");
  }
  if (!participantIdsOf(preSnap.data()).includes(callerUid)) {
    throw new HttpsError("permission-denied", "لست مشاركاً في المحادثة");
  }

  const media = input.media
    ? { ...input.media, ...(await verifyStoredMedia(bucket, callerUid, input)) }
    : null;

  return db.runTransaction(async (tx) => {
    const convSnap = await tx.get(convRef);
    const msgSnap = await tx.get(msgRef);
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "المحادثة غير موجودة");
    }
    const participantIds = participantIdsOf(convSnap.data());
    if (!participantIds.includes(callerUid)) {
      throw new HttpsError("permission-denied", "لست مشاركاً في المحادثة");
    }

    if (msgSnap.exists) {
      const existing = msgSnap.data() ?? {};
      if (existing.senderId === callerUid) {
        return {
          conversationId: input.conversationId,
          messageId: input.messageId,
          created: false,
        };
      }
      throw new HttpsError("already-exists", "معرف الرسالة مستخدم");
    }

    const messageDoc: Record<string, unknown> = {
      senderId: callerUid,
      type: input.type,
      text: input.text,
      sentAt: FieldValue.serverTimestamp(),
      deleted: false,
    };
    if (media) {
      messageDoc.media = {
        storagePath: media.storagePath,
        fileName: media.fileName,
        contentType: media.contentType,
        sizeBytes: media.sizeBytes,
        ...(media.durationMs !== null ? { durationMs: media.durationMs } : {}),
      };
    }
    tx.create(msgRef, messageDoc);

    const convUpdate: Record<string, unknown> = {
      lastMessage: messagePreview(input.type, input.text),
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageSenderId: callerUid,
      lastMessageId: input.messageId,
      lastMessageType: input.type,
      updatedAt: FieldValue.serverTimestamp(),
    };
    for (const uid of participantIds) {
      if (uid !== callerUid) {
        convUpdate[`unreadCounts.${uid}`] = FieldValue.increment(1);
      }
    }
    tx.update(convRef, convUpdate);

    return {
      conversationId: input.conversationId,
      messageId: input.messageId,
      created: true,
    };
  });
}

export const sendChatMessage = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("sendChatMessage");
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }
    return sendChatMessageCore(
      { db: admin.firestore(), bucket: admin.storage().bucket() },
      callerUid,
      request.data,
    );
  },
);
