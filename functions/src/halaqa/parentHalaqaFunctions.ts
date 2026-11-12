/**
 * Parent read path for a linked child's Halaqat.
 *
 * Firestore Rules cannot hide fields, and a halaqat document carries the full
 * roster (`studentIds`) and possibly a legacy `meetingLink`, so Parents never
 * read halaqat directly. This callable returns only the fields the parent UI
 * renders (name and assigned staff ids) for Halaqat whose roster contains a
 * child linked to the caller in their own `parentProfiles` doc.
 */
import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadCallerRole, requireCallerUid, stringList } from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";

export const PARENT_CHILD_HALAQAT_LIMIT = 10;

export interface ParentChildHalaqa {
  id: string;
  name: string;
  teacherId: string;
  supervisorId: string;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Parent-safe projection of one halaqat doc. */
export function toParentChildHalaqa(id: string, data: Record<string, unknown>): ParentChildHalaqa {
  return {
    id,
    name: text(data.name),
    teacherId: text(data.teacherId),
    supervisorId: text(data.supervisorId),
  };
}

export async function getParentChildHalaqatCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ halaqat: ParentChildHalaqa[] }> {
  const uid = requireCallerUid(callerUid);
  const role = await loadCallerRole(db, uid);
  if (role !== "parent") {
    throw new HttpsError("permission-denied", "هذه الخدمة لأولياء الأمور فقط");
  }

  const requested = data.studentId;
  const studentId = text(requested);
  if (typeof requested !== "string" || studentId.length === 0) {
    throw new HttpsError("invalid-argument", "معرّف الطالب مطلوب");
  }

  const profile = await db.collection("parentProfiles").doc(uid).get();
  const linked = new Set(stringList(profile.data()?.childrenIds));
  if (!linked.has(studentId)) {
    throw new HttpsError("permission-denied", "هذا الطالب غير مرتبط بحسابك");
  }

  const snap = await db
    .collection("halaqat")
    .where("studentIds", "array-contains", studentId)
    .limit(PARENT_CHILD_HALAQAT_LIMIT)
    .get();
  const halaqat = snap.docs
    .map((d) => toParentChildHalaqa(d.id, d.data() as Record<string, unknown>))
    .sort((a, b) => a.id.localeCompare(b.id));
  return { halaqat };
}

export const getParentChildHalaqat = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("getParentChildHalaqat");
    return getParentChildHalaqatCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
