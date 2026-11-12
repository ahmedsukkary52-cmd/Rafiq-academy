/**
 * Admin group: one backend-managed conversation whose members are exactly
 * the users allowed to act as Admin right now (`activeRoleOf(...) === "admin"`).
 *
 * Pure decision logic only; Firestore I/O lives in syncAdminGroupConversation.
 */

import { activeRoleOf } from "../authority/callerContext";
import { sameStringSet } from "./halaqaGroupSync";

export const ADMIN_GROUP_KIND = "admin_group";
export const ADMIN_GROUP_CONVERSATION_ID = "admin_internal_group";
export const ADMIN_GROUP_TITLE = "مجموعة الإدارة";

/** Fields a client may never send: membership is derived from users/ only. */
export const ADMIN_GROUP_CLIENT_FORBIDDEN_FIELDS = [
  "participantIds",
  "participants",
  "memberIds",
  "add",
  "remove",
  "uids",
] as const;

export type AdminGroupMember = { uid: string; role: "admin"; name: string };

export type AdminUserRecord = { uid: string; data: Record<string, unknown> | undefined };

export type AdminGroupDecision =
  | { action: "absent"; participantIds: string[] }
  | { action: "create"; participantIds: string[]; participants: AdminGroupMember[] }
  | {
      action: "update";
      participantIds: string[];
      participants: AdminGroupMember[];
      unreadCounts: Record<string, number>;
    }
  | { action: "noop"; participantIds: string[] };

export function isAdminGroupEligible(data: Record<string, unknown> | undefined): boolean {
  return activeRoleOf(data) === "admin";
}

function nameOf(data: Record<string, unknown> | undefined): string {
  return typeof data?.name === "string" ? data.name.trim() : "";
}

export function buildAdminGroupMembers(users: readonly AdminUserRecord[]): AdminGroupMember[] {
  const byUid = new Map<string, AdminGroupMember>();
  for (const { uid, data } of users) {
    const id = typeof uid === "string" ? uid.trim() : "";
    if (!id || !isAdminGroupEligible(data)) continue;
    byUid.set(id, { uid: id, role: "admin", name: nameOf(data) });
  }
  return [...byUid.values()].sort((a, b) => (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));
}

/** True when a users/{uid} write can change the admin group projection. */
export function adminGroupRelevantChange(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): boolean {
  const wasMember = isAdminGroupEligible(before);
  const isMember = isAdminGroupEligible(after);
  if (wasMember !== isMember) return true;
  return isMember && nameOf(before) !== nameOf(after);
}

function sameMembers(existing: unknown, members: readonly AdminGroupMember[]): boolean {
  if (!Array.isArray(existing) || existing.length !== members.length) return false;
  const current = new Map<string, string>();
  for (const p of existing) {
    if (!p || typeof p !== "object") return false;
    const { uid, role, name } = p as Record<string, unknown>;
    if (typeof uid !== "string" || role !== "admin") return false;
    current.set(uid, typeof name === "string" ? name : "");
  }
  return members.every((m) => current.get(m.uid) === m.name);
}

function prunedUnreadCounts(raw: unknown, ids: readonly string[]): Record<string, number> {
  const source = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
  const out: Record<string, number> = {};
  for (const id of ids) {
    const n = source[id];
    out[id] = typeof n === "number" && Number.isFinite(n) && n >= 0 ? n : 0;
  }
  return out;
}

/**
 * [existing] is the current conversation document (null when absent).
 * Throws when the reserved id holds a conversation of another kind, so the
 * sync never takes over a direct chat or another group.
 */
export function decideAdminGroupSync(params: {
  users: readonly AdminUserRecord[];
  existing: Record<string, unknown> | null;
  allowCreate: boolean;
}): AdminGroupDecision {
  const participants = buildAdminGroupMembers(params.users);
  const participantIds = participants.map((m) => m.uid);
  const { existing } = params;

  if (!existing) {
    return params.allowCreate
      ? { action: "create", participantIds, participants }
      : { action: "absent", participantIds };
  }
  if (existing.kind !== ADMIN_GROUP_KIND) {
    throw new Error(`conversation ${ADMIN_GROUP_CONVERSATION_ID} is not an admin group`);
  }

  const currentIds = Array.isArray(existing.participantIds)
    ? existing.participantIds.filter((v): v is string => typeof v === "string")
    : [];
  const unread = existing.unreadCounts;
  const unreadKeys = unread && typeof unread === "object" ? Object.keys(unread) : [];
  const unchanged =
    existing.title === ADMIN_GROUP_TITLE &&
    currentIds.length === participantIds.length &&
    sameStringSet(currentIds, participantIds) &&
    sameMembers(existing.participants, participants) &&
    sameStringSet(unreadKeys, participantIds);
  if (unchanged) return { action: "noop", participantIds };

  return {
    action: "update",
    participantIds,
    participants,
    unreadCounts: prunedUnreadCounts(unread, participantIds),
  };
}
