/**
 * Parent read path for a linked child's weekly Halaqa schedule (J.10).
 *
 * Parents never read halaqat directly (roster + legacy meetingLink). This
 * callable returns only what the parent schedule screen renders: the Halaqa
 * name and each slot's day/startTime/endTime. Never the roster, links, staff
 * ids or slot ids.
 */
import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadCallerRole, requireCallerUid, stringList } from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";
import { MAX_SLOTS_PER_HALAQA } from "./halaqaScheduleFunctions";

export interface ParentScheduleSlot {
  day: string;
  startTime: string;
  endTime: string;
}

export interface ParentChildSchedule {
  halaqaId: string;
  name: string;
  schedule: ParentScheduleSlot[];
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function requiredId(raw: unknown, message: string): string {
  const value = text(raw);
  if (typeof raw !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", message);
  }
  return value;
}

/** Parent-safe projection of one halaqat doc's schedule. */
export function toParentChildSchedule(
  halaqaId: string,
  data: Record<string, unknown>,
): ParentChildSchedule {
  const raw = Array.isArray(data.schedule) ? data.schedule : [];
  const schedule: ParentScheduleSlot[] = [];
  for (const entry of raw) {
    if (schedule.length >= MAX_SLOTS_PER_HALAQA) break;
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
    const slot = entry as Record<string, unknown>;
    schedule.push({
      day: text(slot.day),
      startTime: text(slot.startTime),
      endTime: text(slot.endTime),
    });
  }
  return { halaqaId, name: text(data.name), schedule };
}

export async function getParentChildScheduleCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ParentChildSchedule> {
  const uid = requireCallerUid(callerUid);
  const role = await loadCallerRole(db, uid);
  if (role !== "parent") {
    throw new HttpsError("permission-denied", "هذه الخدمة لأولياء الأمور فقط");
  }

  const studentId = requiredId(data.studentId, "معرّف الطالب مطلوب");
  const halaqaId = requiredId(data.halaqaId, "معرّف الحلقة مطلوب");

  const profile = await db.collection("parentProfiles").doc(uid).get();
  const linked = new Set(stringList(profile.data()?.childrenIds));
  if (!linked.has(studentId)) {
    throw new HttpsError("permission-denied", "هذا الطالب غير مرتبط بحسابك");
  }

  // A missing Halaqa and one whose roster lacks the child answer alike, so a
  // parent cannot probe which Halaqa ids exist.
  const snap = await db.collection("halaqat").doc(halaqaId).get();
  const halaqa = snap.exists ? (snap.data() as Record<string, unknown>) : undefined;
  if (!halaqa || !stringList(halaqa.studentIds).includes(studentId)) {
    throw new HttpsError("permission-denied", "الطالب ليس ضمن هذه الحلقة");
  }
  return toParentChildSchedule(halaqaId, halaqa);
}

export const getParentChildSchedule = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("getParentChildSchedule");
    return getParentChildScheduleCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
