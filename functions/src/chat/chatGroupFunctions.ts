/**
 * Admin-managed dynamic chat groups + message reactions.
 *
 * Groups are ordinary `conversations` documents (`kind: custom_group`), so the
 * existing rules already confine conversation, messages and chat media to
 * current `participantIds`: removing a member revokes access to the history
 * and every attachment immediately. Students are not added to custom groups
 * (they communicate through their halaqa group / staff only).
 *
 * Reactions are a per-user map on the message, written only here.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { requireCallerUid } from "../authority/callerContext";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { loadUserRole } from "./loadChatRelationships";

export const CUSTOM_GROUP_KIND = "custom_group";
export const CUSTOM_GROUP_ID_PREFIX = "group_";
export const GROUP_TITLE_MAX = 60;
export const GROUP_DESCRIPTION_MAX = 500;
export const GROUP_MAX_MEMBERS = 256;
export const GROUP_MEMBER_ROLES = ["teacher", "supervisor", "parent", "admin"] as const;
export const CHAT_REACTIONS = ["like", "heart", "laugh", "sad"] as const;
export type ChatReaction = (typeof CHAT_REACTIONS)[number];

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{12,64}$/;

type Db = admin.firestore.Firestore;

type MemberStub = { uid: string; role: string; name: string };

function text(raw: unknown): string {
  return typeof raw === "string" ? raw.trim() : "";
}

function idList(raw: unknown): string[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) throw new HttpsError("invalid-argument", "قائمة الأعضاء غير صالحة");
  const out = new Set<string>();
  for (const v of raw) {
    const id = text(v);
    if (!id || id.includes("/") || id.length > 128) {
      throw new HttpsError("invalid-argument", "معرّف عضو غير صالح");
    }
    out.add(id);
  }
  return [...out];
}

function checkText(value: string, label: string, max: number, required: boolean): string {
  if (required && value.length < 2) throw new HttpsError("invalid-argument", `${label} قصير جداً`);
  if (value.length > max) throw new HttpsError("invalid-argument", `${label} أطول من ${max} حرف`);
  const violation = contactInfoViolation(value);
  if (violation) throw new HttpsError("invalid-argument", violation);
  return value;
}

async function requireAdmin(db: Db, callerUid: string | undefined): Promise<string> {
  const uid = requireCallerUid(callerUid);
  if ((await loadUserRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "إدارة المجموعات متاحة للمسؤول فقط");
  }
  return uid;
}

/** Loads and validates prospective members (active, allowed role). */
async function loadMembers(db: Db, ids: string[]): Promise<MemberStub[]> {
  if (ids.length === 0) return [];
  const snaps = await db.getAll(...ids.map((id) => db.collection("users").doc(id)));
  return snaps.map((snap) => {
    const data = snap.data() ?? {};
    if (!snap.exists || data.isActive !== true) {
      throw new HttpsError("failed-precondition", "أحد الأعضاء غير موجود أو غير نشط");
    }
    const role = text(data.role);
    if (!(GROUP_MEMBER_ROLES as readonly string[]).includes(role)) {
      throw new HttpsError("failed-precondition", "لا يمكن إضافة الطلاب إلى مجموعات مخصّصة");
    }
    return { uid: snap.id, role, name: text(data.name) };
  });
}

function requireGroup(snap: admin.firestore.DocumentSnapshot) {
  if (!snap.exists) throw new HttpsError("not-found", "المجموعة غير موجودة");
  const data = snap.data() ?? {};
  if (data.kind !== CUSTOM_GROUP_KIND) {
    throw new HttpsError("failed-precondition", "هذه المحادثة ليست مجموعة قابلة للإدارة");
  }
  return data;
}

export async function adminCreateChatGroupCore(
  db: Db,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ conversationId: string; created: boolean }> {
  const uid = await requireAdmin(db, callerUid);
  const requestId = text(data.requestId);
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "معرّف الطلب غير صالح");
  }
  const title = checkText(text(data.title), "اسم المجموعة", GROUP_TITLE_MAX, true);
  const description = checkText(text(data.description), "الوصف", GROUP_DESCRIPTION_MAX, false);
  const memberIds = idList(data.memberIds).filter((id) => id !== uid);
  if (memberIds.length === 0) throw new HttpsError("invalid-argument", "أضف عضواً واحداً على الأقل");
  if (memberIds.length + 1 > GROUP_MAX_MEMBERS) {
    throw new HttpsError("invalid-argument", `الحد الأقصى ${GROUP_MAX_MEMBERS} عضواً`);
  }

  const conversationId = `${CUSTOM_GROUP_ID_PREFIX}${requestId}`;
  const ref = db.collection("conversations").doc(conversationId);
  const existing = await ref.get();
  if (existing.exists) {
    const prev = existing.data() ?? {};
    if (prev.kind === CUSTOM_GROUP_KIND && prev.createdBy === uid && prev.title === title) {
      return { conversationId, created: false };
    }
    throw new HttpsError("already-exists", "معرّف الطلب مستخدم لمجموعة أخرى");
  }

  const members = await loadMembers(db, [uid, ...memberIds]);
  const participantIds = members.map((m) => m.uid);
  const now = FieldValue.serverTimestamp();
  await ref.create({
    kind: CUSTOM_GROUP_KIND,
    title,
    description,
    imagePath: null,
    participantIds,
    participants: members,
    groupAdminIds: [uid],
    lastMessage: null,
    lastMessageAt: now,
    lastMessageSenderId: null,
    unreadCounts: Object.fromEntries(participantIds.map((id) => [id, 0])),
    createdAt: now,
    updatedAt: now,
    createdBy: uid,
  });
  await writeAuditLog(
    {
      actor: adminActor(uid),
      action: AUDIT_ACTION.chatGroupCreate,
      targetType: AUDIT_TARGET_TYPE.conversation,
      targetId: conversationId,
      metadata: { createdCount: participantIds.length, requestId },
      source: "adminCreateChatGroup",
    },
    db,
  );
  return { conversationId, created: true };
}

export async function adminUpdateChatGroupCore(
  db: Db,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ conversationId: string }> {
  await requireAdmin(db, callerUid);
  const conversationId = text(data.conversationId);
  if (!conversationId.startsWith(CUSTOM_GROUP_ID_PREFIX)) {
    throw new HttpsError("invalid-argument", "المجموعة غير صالحة");
  }
  const update: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
  if (data.title !== undefined) {
    update.title = checkText(text(data.title), "اسم المجموعة", GROUP_TITLE_MAX, true);
  }
  if (data.description !== undefined) {
    update.description = checkText(text(data.description), "الوصف", GROUP_DESCRIPTION_MAX, false);
  }
  if (data.imagePath !== undefined) {
    const path = text(data.imagePath);
    const parts = path.split("/");
    if (
      path &&
      (parts.length !== 3 ||
        parts[0] !== "chat_group_images" ||
        parts[1] !== conversationId ||
        !/^[A-Za-z0-9._-]{1,80}$/.test(parts[2]))
    ) {
      throw new HttpsError("invalid-argument", "مسار صورة المجموعة غير صالح");
    }
    update.imagePath = path || null;
  }
  const ref = db.collection("conversations").doc(conversationId);
  await db.runTransaction(async (tx) => {
    requireGroup(await tx.get(ref));
    tx.update(ref, update);
  });
  return { conversationId };
}

export async function adminSetChatGroupMembersCore(
  db: Db,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ conversationId: string; participantIds: string[] }> {
  const uid = await requireAdmin(db, callerUid);
  const conversationId = text(data.conversationId);
  const add = idList(data.add);
  const remove = idList(data.remove);
  if (add.length === 0 && remove.length === 0) {
    throw new HttpsError("invalid-argument", "لا توجد تغييرات على الأعضاء");
  }
  if (add.some((id) => remove.includes(id))) {
    throw new HttpsError("invalid-argument", "لا يمكن إضافة العضو وإزالته معاً");
  }
  const newcomers = await loadMembers(db, add);
  const ref = db.collection("conversations").doc(conversationId);

  const participantIds = await db.runTransaction(async (tx) => {
    const group = requireGroup(await tx.get(ref));
    const current: MemberStub[] = Array.isArray(group.participants) ? group.participants : [];
    const byUid = new Map(current.map((m) => [m.uid, m]));
    for (const m of newcomers) byUid.set(m.uid, m);
    for (const id of remove) byUid.delete(id);
    const next = [...byUid.values()];
    if (next.length < 2) throw new HttpsError("failed-precondition", "يجب أن تضم المجموعة عضوين على الأقل");
    if (next.length > GROUP_MAX_MEMBERS) {
      throw new HttpsError("failed-precondition", `الحد الأقصى ${GROUP_MAX_MEMBERS} عضواً`);
    }
    const admins = (Array.isArray(group.groupAdminIds) ? group.groupAdminIds : [])
      .filter((id: unknown) => typeof id === "string" && byUid.has(id));
    if (admins.length === 0) admins.push(uid);
    const ids = next.map((m) => m.uid);
    const update: Record<string, unknown> = {
      participantIds: ids,
      participants: next,
      groupAdminIds: admins,
      updatedAt: FieldValue.serverTimestamp(),
    };
    for (const m of newcomers) {
      if (!current.some((c) => c.uid === m.uid)) update[`unreadCounts.${m.uid}`] = 0;
    }
    for (const id of remove) update[`unreadCounts.${id}`] = FieldValue.delete();
    tx.update(ref, update);
    return ids;
  });

  await writeAuditLog(
    {
      actor: adminActor(uid),
      action: AUDIT_ACTION.chatGroupMembersChange,
      targetType: AUDIT_TARGET_TYPE.conversation,
      targetId: conversationId,
      metadata: { createdCount: add.length, deletedCount: remove.length },
      source: "adminSetChatGroupMembers",
    },
    db,
  );
  return { conversationId, participantIds };
}

export async function reactToChatMessageCore(
  db: Db,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ reaction: ChatReaction | null }> {
  const uid = requireCallerUid(callerUid);
  // Match send/edit/delete: participantIds alone is not enough — deactivated /
  // first-login-blocked accounts must not mutate reactions.
  const role = await loadUserRole(db, uid);
  if (!role) {
    throw new HttpsError("permission-denied", "الحساب غير مفعّل");
  }
  const conversationId = text(data.conversationId);
  const messageId = text(data.messageId);
  if (!conversationId || !messageId || conversationId.includes("/") || messageId.includes("/")) {
    throw new HttpsError("invalid-argument", "الرسالة غير صالحة");
  }
  const raw = data.reaction ?? null;
  if (raw !== null && !(CHAT_REACTIONS as readonly unknown[]).includes(raw)) {
    throw new HttpsError("invalid-argument", "تفاعل غير مدعوم");
  }
  const reaction = raw as ChatReaction | null;
  const convRef = db.collection("conversations").doc(conversationId);
  const msgRef = convRef.collection("messages").doc(messageId);
  await db.runTransaction(async (tx) => {
    const [conv, msg] = await Promise.all([tx.get(convRef), tx.get(msgRef)]);
    const ids = conv.data()?.participantIds;
    if (!conv.exists || !Array.isArray(ids) || !ids.includes(uid)) {
      throw new HttpsError("permission-denied", "لست مشاركاً في المحادثة");
    }
    if (!msg.exists) throw new HttpsError("not-found", "الرسالة غير موجودة");
    if (msg.data()?.deleted === true) {
      throw new HttpsError("failed-precondition", "لا يمكن التفاعل مع رسالة محذوفة");
    }
    tx.update(msgRef, {
      [`reactions.${uid}`]: reaction ?? FieldValue.delete(),
    });
  });
  return { reaction };
}

const region = { region: "europe-west1" };
const payload = (d: unknown) => (d ?? {}) as Record<string, unknown>;

export const adminCreateChatGroup = onCall(region, async (request) => {
  assertBackendAllowed("adminCreateChatGroup");
  return adminCreateChatGroupCore(admin.firestore(), request.auth?.uid, payload(request.data));
});

export const adminUpdateChatGroup = onCall(region, async (request) => {
  assertBackendAllowed("adminUpdateChatGroup");
  return adminUpdateChatGroupCore(admin.firestore(), request.auth?.uid, payload(request.data));
});

export const adminSetChatGroupMembers = onCall(region, async (request) => {
  assertBackendAllowed("adminSetChatGroupMembers");
  return adminSetChatGroupMembersCore(admin.firestore(), request.auth?.uid, payload(request.data));
});

export const reactToChatMessage = onCall(region, async (request) => {
  assertBackendAllowed("reactToChatMessage");
  return reactToChatMessageCore(admin.firestore(), request.auth?.uid, payload(request.data));
});
