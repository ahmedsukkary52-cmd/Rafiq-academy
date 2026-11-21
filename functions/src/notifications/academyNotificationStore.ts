/**
 * PH-02 / C11 — Firestore I/O for server-owned academy notifications.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

import {
  isEligibleNotificationRecipient,
  ROLE_NOTIFICATION_AUDIENCES,
  type InAppNotification,
} from "./academyNotifications";
import { assertSafeDataPayload } from "./evaluationNotification";
import {
  NOTIFICATIONS_COLLECTION,
  PARENT_PROFILES_COLLECTION,
  USERS_COLLECTION,
} from "./fcmTokenContract";

const IN_QUERY_LIMIT = 30;
const WRITE_BATCH_LIMIT = 400;

function chunks<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

function uniqueIds(ids: readonly string[]): string[] {
  return [...new Set(ids.map((id) => id.trim()).filter((id) => id !== ""))];
}

/** D12 — parents come from parentProfiles.childrenIds only (CF/Admin written). */
export async function loadParentIdsByStudent(
  db: admin.firestore.Firestore,
  studentIds: readonly string[],
): Promise<Map<string, string[]>> {
  const wanted = uniqueIds(studentIds);
  const out = new Map<string, string[]>();
  for (const id of wanted) out.set(id, []);

  for (const chunk of chunks(wanted, IN_QUERY_LIMIT)) {
    const snap = await db
      .collection(PARENT_PROFILES_COLLECTION)
      .where("childrenIds", "array-contains-any", chunk)
      .get();
    for (const doc of snap.docs) {
      const children = doc.data().childrenIds;
      if (!Array.isArray(children)) continue;
      for (const child of children) {
        if (typeof child !== "string") continue;
        const list = out.get(child.trim());
        if (list && !list.includes(doc.id)) list.push(doc.id);
      }
    }
  }
  for (const list of out.values()) list.sort();
  return out;
}

/** Display enrichment only — never part of the data payload. */
export async function loadStudentNames(
  db: admin.firestore.Firestore,
  studentIds: readonly string[],
): Promise<Map<string, string>> {
  const wanted = uniqueIds(studentIds);
  const out = new Map<string, string>();
  if (wanted.length === 0) return out;
  const refs = wanted.map((id) => db.collection(USERS_COLLECTION).doc(id));
  for (const chunk of chunks(refs, 100)) {
    const snaps = await db.getAll(...chunk);
    for (const snap of snaps) {
      const name = snap.data()?.name;
      if (typeof name === "string" && name.trim() !== "") {
        out.set(snap.id, name.trim());
      }
    }
  }
  return out;
}

const ROLE_AUDIENCES = new Set<string>(ROLE_NOTIFICATION_AUDIENCES);

/** Drops uid audiences whose profile is deactivated or pending first login. */
export async function retainEligibleNotifications(
  db: admin.firestore.Firestore,
  notifications: readonly InAppNotification[],
): Promise<InAppNotification[]> {
  const uids = uniqueIds(
    notifications
      .map((n) => n.audience.trim())
      .filter((audience) => audience !== "" && !ROLE_AUDIENCES.has(audience)),
  );
  if (uids.length === 0) return [...notifications];
  const eligible = new Set<string>();
  const refs = uids.map((id) => db.collection(USERS_COLLECTION).doc(id));
  for (const chunk of chunks(refs, 100)) {
    const snaps = await db.getAll(...chunk);
    for (const snap of snaps) {
      if (isEligibleNotificationRecipient(snap.data())) eligible.add(snap.id);
    }
  }
  return notifications.filter((n) => {
    const audience = n.audience.trim();
    return ROLE_AUDIENCES.has(audience) || eligible.has(audience);
  });
}

/**
 * Deterministic-id upsert. Re-publishing the same fact replaces its content
 * and makes it unread again (same semantics as the retired client path).
 * Deactivated and first-login-pending uid audiences are omitted.
 */
export async function writeInAppNotifications(
  db: admin.firestore.Firestore,
  notifications: readonly InAppNotification[],
): Promise<number> {
  const eligible = await retainEligibleNotifications(db, notifications);
  const byId = new Map<string, InAppNotification>();
  for (const n of eligible) {
    if (n.audience.trim() === "") continue;
    assertSafeDataPayload(n.data);
    byId.set(n.notificationId, n);
  }
  const unique = [...byId.values()];
  for (const chunk of chunks(unique, WRITE_BATCH_LIMIT)) {
    const batch = db.batch();
    for (const n of chunk) {
      batch.set(db.collection(NOTIFICATIONS_COLLECTION).doc(n.notificationId), {
        audience: n.audience,
        title: n.title,
        body: n.body,
        type: n.type,
        readBy: [] as string[],
        hasAudioAlert: false,
        createdAt: FieldValue.serverTimestamp(),
        data: n.data,
      });
    }
    await batch.commit();
  }
  return unique.length;
}
