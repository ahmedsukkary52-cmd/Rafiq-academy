/**
 * Parent achievements read path.
 *
 * Firestore Rules deny parent list queries on `achievements` (a rules `get()`
 * on parentProfiles cannot back a list query). Parents read their children's
 * achievements only through this callable: the caller is `request.auth`, the
 * children come from the caller's own `parentProfiles` doc, and every returned
 * field is limited to what the parent UI renders.
 */

import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadCallerRole, requireCallerUid, stringList } from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";

export const PARENT_ACHIEVEMENTS_MAX_CHILDREN = 20;
export const PARENT_ACHIEVEMENTS_PER_QUERY_LIMIT = 100;
export const PARENT_ACHIEVEMENTS_MAX_RESULTS = 200;

export interface ParentAchievement {
  id: string;
  studentId: string;
  type: string;
  title: string;
  description: string;
  imageUrl: string | null;
  issuedBy: string;
  dateMillis: number;
  recipientStudentIds: string[];
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function dateMillisOf(data: Record<string, unknown>): number {
  const raw = data.date ?? data.grantedAt;
  if (raw instanceof Timestamp) return raw.toMillis();
  if (raw instanceof Date) return raw.getTime();
  if (raw && typeof (raw as { toMillis?: unknown }).toMillis === "function") {
    return (raw as { toMillis: () => number }).toMillis();
  }
  return 0;
}

/**
 * Recipients of [data] (credited `recipientStudentIds`, else legacy
 * `studentId`), restricted to [linked]. Other students' IDs never leave the
 * server.
 */
function linkedRecipients(data: Record<string, unknown>, linked: ReadonlySet<string>): string[] {
  const all = Array.isArray(data.recipientStudentIds)
    ? stringList(data.recipientStudentIds)
    : [text(data.studentId)].filter((id) => id.length > 0);
  const legacy = text(data.studentId);
  if (legacy && !all.includes(legacy)) all.push(legacy);
  return [...new Set(all)].filter((id) => linked.has(id));
}

/**
 * Parent-safe projection of one achievement doc, or null when none of its
 * recipients is in [linked].
 */
export function toParentAchievement(
  id: string,
  data: Record<string, unknown>,
  linked: ReadonlySet<string>,
): ParentAchievement | null {
  const recipients = linkedRecipients(data, linked);
  if (recipients.length === 0) return null;
  const primary = text(data.studentId);
  const title = text(data.title) || text(data.note) || text(data.type);
  const imageUrl = text(data.imageUrl);
  return {
    id,
    studentId: linked.has(primary) ? primary : recipients[0],
    type: text(data.type),
    title,
    description: text(data.description),
    imageUrl: imageUrl.length > 0 ? imageUrl : null,
    issuedBy: text(data.issuedBy) || text(data.grantedBy),
    dateMillis: dateMillisOf(data),
    recipientStudentIds: recipients,
  };
}

/** Deduplicated by doc id, newest first, capped. */
export function mergeParentAchievements(
  docs: Iterable<{ id: string; data: Record<string, unknown> }>,
  linked: ReadonlySet<string>,
  maxResults = PARENT_ACHIEVEMENTS_MAX_RESULTS,
): ParentAchievement[] {
  const byId = new Map<string, ParentAchievement>();
  for (const doc of docs) {
    if (byId.has(doc.id)) continue;
    const item = toParentAchievement(doc.id, doc.data, linked);
    if (item) byId.set(doc.id, item);
  }
  return [...byId.values()]
    .sort((a, b) => b.dateMillis - a.dateMillis || a.id.localeCompare(b.id))
    .slice(0, maxResults);
}

export async function getParentAchievementsCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ achievements: ParentAchievement[] }> {
  const uid = requireCallerUid(callerUid);
  const role = await loadCallerRole(db, uid);
  if (role !== "parent") {
    throw new HttpsError("permission-denied", "هذه الخدمة لأولياء الأمور فقط");
  }

  const profile = await db.collection("parentProfiles").doc(uid).get();
  const linkedIds = [...new Set(stringList(profile.data()?.childrenIds))];
  const linked = new Set(linkedIds);

  const requested = data.studentId;
  let targets: string[];
  if (requested == null || requested === "") {
    targets = linkedIds;
  } else {
    const studentId = text(requested);
    if (typeof requested !== "string" || !linked.has(studentId)) {
      throw new HttpsError("permission-denied", "هذا الطالب غير مرتبط بحسابك");
    }
    targets = [studentId];
  }
  targets = targets.slice(0, PARENT_ACHIEVEMENTS_MAX_CHILDREN);
  if (targets.length === 0) return { achievements: [] };

  const col = db.collection("achievements");
  const snaps = await Promise.all(
    targets.flatMap((childId) => [
      col
        .where("recipientStudentIds", "array-contains", childId)
        .limit(PARENT_ACHIEVEMENTS_PER_QUERY_LIMIT)
        .get(),
      col
        .where("studentId", "==", childId)
        .limit(PARENT_ACHIEVEMENTS_PER_QUERY_LIMIT)
        .get(),
    ]),
  );
  const docs = snaps.flatMap((snap) =>
    snap.docs.map((d) => ({ id: d.id, data: d.data() as Record<string, unknown> })),
  );
  return { achievements: mergeParentAchievements(docs, new Set(targets)) };
}

export const getParentAchievements = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("getParentAchievements");
    return getParentAchievementsCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
