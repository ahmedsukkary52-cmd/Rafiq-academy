/**
 * Staff read path for a halaqa's awards.
 *
 * Firestore Rules give teachers and supervisors no list access to
 * `achievements`: a multi-halaqa grant is found by `halaqaIds array-contains`,
 * and rules cannot prove from that query that the caller serves the halaqa.
 * The caller here is `request.auth`; the halaqa's teacher or supervisor (or
 * an Admin) receives that halaqa's grants, limited to the fields the awards
 * screen renders.
 */

import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadCallerRole, requireCallerUid, requireText, stringList } from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";
import { canGrantInHalaqa } from "./awardFunctions";

export const HALAQA_AWARDS_PER_QUERY_LIMIT = 200;
export const HALAQA_AWARDS_MAX_RESULTS = 200;

const TEXT_FIELDS = [
  "studentId",
  "studentName",
  "studentImageUrl",
  "type",
  "title",
  "note",
  "description",
  "imageUrl",
  "imageStoragePath",
  "grantedBy",
  "issuedBy",
  "halaqaId",
  "halaqaName",
] as const;
const LIST_FIELDS = ["halaqaIds", "halaqaNames", "recipientStudentIds"] as const;

export type HalaqaAward = Record<string, string | string[] | number>;

function millisOf(raw: unknown): number {
  if (raw instanceof Timestamp) return raw.toMillis();
  if (raw instanceof Date) return raw.getTime();
  if (raw && typeof (raw as { toMillis?: unknown }).toMillis === "function") {
    return (raw as { toMillis: () => number }).toMillis();
  }
  return 0;
}

/** Award-screen projection of one achievement doc. */
export function toHalaqaAward(id: string, data: Record<string, unknown>): HalaqaAward {
  const out: HalaqaAward = { id, dateMillis: millisOf(data.date ?? data.grantedAt) };
  for (const field of TEXT_FIELDS) {
    if (typeof data[field] === "string") out[field] = data[field] as string;
  }
  for (const field of LIST_FIELDS) {
    if (Array.isArray(data[field])) out[field] = stringList(data[field]);
  }
  if (typeof data.recipientCount === "number") out.recipientCount = data.recipientCount;
  return out;
}

export async function getHalaqaAwardsCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ awards: HalaqaAward[] }> {
  const uid = requireCallerUid(callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId");
  const role = await loadCallerRole(db, uid);
  if (role !== "admin" && role !== "teacher" && role !== "supervisor") {
    throw new HttpsError("permission-denied", "جوائز الحلقة متاحة لمعلمها ومشرفها فقط");
  }
  const halaqa = await db.collection("halaqat").doc(halaqaId).get();
  if (!halaqa.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
  if (!canGrantInHalaqa(role, uid, halaqa.data() ?? {})) {
    throw new HttpsError("permission-denied", "الحلقة خارج نطاقك");
  }

  const col = db.collection("achievements");
  const [byId, byIds] = await Promise.all([
    col.where("halaqaId", "==", halaqaId).limit(HALAQA_AWARDS_PER_QUERY_LIMIT).get(),
    col.where("halaqaIds", "array-contains", halaqaId).limit(HALAQA_AWARDS_PER_QUERY_LIMIT).get(),
  ]);
  const byDoc = new Map<string, HalaqaAward>();
  for (const doc of [...byId.docs, ...byIds.docs]) {
    if (!byDoc.has(doc.id)) byDoc.set(doc.id, toHalaqaAward(doc.id, doc.data()));
  }
  const awards = [...byDoc.values()]
    .sort((a, b) => (b.dateMillis as number) - (a.dateMillis as number)
      || String(a.id).localeCompare(String(b.id)))
    .slice(0, HALAQA_AWARDS_MAX_RESULTS);
  return { awards };
}

export const getHalaqaAwards = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("getHalaqaAwards");
    return getHalaqaAwardsCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
