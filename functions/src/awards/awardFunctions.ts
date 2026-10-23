/**
 * PH-02 closure — staff award grant is server-authoritative.
 *
 * Grant scope follows SECURITY_IMPLEMENTATION_SPEC §2 (awards row): Admin any
 * halaqa, Supervisor supervised halaqat, Teacher own halaqat. Recipients must
 * be on the roster of a scoped halaqa. The star counter is applied here with
 * the fixed per-recipient value (+1 star); the client never sends an amount or
 * a balance. `points` is quarantined (P0 decision §3) and no longer credited;
 * AWARD_POINTS_PER_RECIPIENT is kept only as the historical value.
 *
 * Awards are append-only (no revoke) — `achievements` update/delete stay
 * denied in rules. Replaying the same `awardId` never credits twice, and a
 * replay with a different payload is rejected instead of reported as granted.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  loadCallerRole,
  optionalText,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";

export const AWARD_POINTS_PER_RECIPIENT = 10;
export const AWARD_STARS_PER_RECIPIENT = 1;

/** One transaction: award doc + one profile update per recipient (< 500). */
export const MAX_AWARD_RECIPIENTS = 400;
export const MAX_AWARD_HALAQAT = 10;

/** Mirror of AwardTypeInfo.firestoreKey (lib/features/awards). */
export const AWARD_TYPE_KEYS: readonly string[] = Object.freeze([
  "completion_badge",
  "performance_stars",
  "perfect_attendance",
  "student_of_week",
  "attendance",
  "completion",
  "performance",
  "achievement",
  "custom",
]);

const AWARD_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
const GRANTOR_ROLES = new Set(["admin", "supervisor", "teacher"]);

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function uniqueIds(raw: unknown): string[] {
  return [...new Set(stringList(raw))];
}

/** Whether [role]/[uid] may grant inside [halaqa]. */
export function canGrantInHalaqa(
  role: string,
  uid: string,
  halaqa: Record<string, unknown>,
): boolean {
  if (role === "admin") return true;
  if (role === "teacher") return text(halaqa.teacherId) === uid;
  if (role === "supervisor") return text(halaqa.supervisorId) === uid;
  return false;
}

/** Credited (grantAward) docs carry a recipient list; record-only ones never do. */
function isCreditedAward(doc: Record<string, unknown>): boolean {
  return Array.isArray(doc.recipientStudentIds);
}

export const AWARD_PAYLOAD_MISMATCH_MESSAGE =
  "معرّف العملية مستخدم لطلب مختلف. لم تُسجَّل هذه البيانات؛ راجع قائمة الجوائز.";

function sameIdSet(stored: unknown, requested: readonly string[]): boolean {
  const a = [...new Set(stringList(stored))].sort();
  const b = [...new Set(requested)].sort();
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

/**
 * A replayed operation id must carry the payload that was committed under
 * it; otherwise the replay would report success for data never written.
 * Compared on the stored canonical fields. Display-only fields and the image
 * are excluded: the client re-uploads the image to a new timestamped path on
 * every attempt, so its URL and path legitimately differ between retries.
 */
function assertSamePayload(matches: boolean): void {
  if (!matches) {
    throw new HttpsError("failed-precondition", AWARD_PAYLOAD_MISMATCH_MESSAGE);
  }
}

export function awardImagePathOk(path: string, uid: string): boolean {
  return path.startsWith(`awards/${uid}/`) && !path.includes("..");
}

export type GrantAwardResult = {
  awardId: string;
  recipientCount: number;
  alreadyGranted: boolean;
};

export async function grantAwardCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<GrantAwardResult> {
  const uid = requireCallerUid(callerUid);
  const awardId = requireText(data.awardId, "awardId", 64);
  if (!AWARD_ID_PATTERN.test(awardId)) {
    throw new HttpsError("invalid-argument", "awardId غير صالح");
  }
  const type = requireText(data.type, "type", 64);
  if (!AWARD_TYPE_KEYS.includes(type)) {
    throw new HttpsError("invalid-argument", "نوع الجائزة غير صالح");
  }
  const title = requireText(data.title, "title", 120);
  const description = optionalText(data.description, 1000);
  const studentName = optionalText(data.studentName, 200);
  const studentImageUrl = optionalText(data.studentImageUrl, 2000);
  const imageUrl = optionalText(data.imageUrl, 2000);
  const imageStoragePath = optionalText(data.imageStoragePath, 300);
  const awardTextViolation =
    contactInfoViolation(title) ??
    contactInfoViolation(description) ??
    contactInfoViolation(studentName);
  if (awardTextViolation) {
    throw new HttpsError("invalid-argument", awardTextViolation);
  }
  if (imageStoragePath && !awardImagePathOk(imageStoragePath, uid)) {
    throw new HttpsError("invalid-argument", "مسار صورة الجائزة غير صالح");
  }

  const recipients = uniqueIds(data.recipientStudentIds);
  if (recipients.length === 0) {
    throw new HttpsError("invalid-argument", "يجب اختيار طالب واحد على الأقل");
  }
  if (recipients.length > MAX_AWARD_RECIPIENTS) {
    throw new HttpsError("invalid-argument", "عدد الطلاب كبير جداً");
  }
  const halaqaIds = uniqueIds(data.halaqaIds);
  const requestedPrimary = text(data.halaqaId);
  if (halaqaIds.length === 0 && requestedPrimary) halaqaIds.push(requestedPrimary);
  if (halaqaIds.length === 0) {
    throw new HttpsError("invalid-argument", "halaqaId مطلوب");
  }
  if (halaqaIds.length > MAX_AWARD_HALAQAT) {
    throw new HttpsError("invalid-argument", "عدد الحلقات كبير جداً");
  }
  const primaryHalaqaId = halaqaIds.includes(requestedPrimary)
    ? requestedPrimary
    : halaqaIds[0];

  const role = await loadCallerRole(db, uid);
  if (!GRANTOR_ROLES.has(role)) {
    throw new HttpsError("permission-denied", "منح الجوائز متاح للمعلم والمشرف والإدارة فقط");
  }

  const awardRef = db.collection("achievements").doc(awardId);
  const halaqaRefs = halaqaIds.map((id) => db.collection("halaqat").doc(id));
  const profileRefs = recipients.map((id) =>
    db.collection("studentProfiles").doc(id),
  );

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(awardRef);
    if (existing.exists) {
      const prior = existing.data() ?? {};
      if (text(prior.grantedBy) !== uid || !isCreditedAward(prior)) {
        throw new HttpsError("already-exists", "معرّف الجائزة مستخدم");
      }
      assertSamePayload(
        text(prior.type) === type &&
          text(prior.title) === title &&
          text(prior.description) === description &&
          text(prior.halaqaId) === primaryHalaqaId &&
          sameIdSet(prior.halaqaIds, halaqaIds) &&
          sameIdSet(prior.recipientStudentIds, recipients),
      );
      return {
        awardId,
        recipientCount: stringList(prior.recipientStudentIds).length,
        alreadyGranted: true,
      };
    }

    const halaqaSnaps = await tx.getAll(...halaqaRefs);
    const roster = new Set<string>();
    const halaqaNames: string[] = [];
    for (const snap of halaqaSnaps) {
      if (!snap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
      const halaqa = snap.data() ?? {};
      if (!canGrantInHalaqa(role, uid, halaqa)) {
        throw new HttpsError("permission-denied", "لا تملك صلاحية منح جوائز في هذه الحلقة");
      }
      for (const id of stringList(halaqa.studentIds)) roster.add(id);
      const name = text(halaqa.name);
      if (name) halaqaNames.push(name);
    }
    for (const studentId of recipients) {
      if (!roster.has(studentId)) {
        throw new HttpsError("permission-denied", "الطالب ليس ضمن الحلقات المختارة");
      }
    }
    const profileSnaps = await tx.getAll(...profileRefs);
    if (profileSnaps.some((s) => !s.exists)) {
      throw new HttpsError("not-found", "ملف الطالب غير موجود");
    }

    const primaryIndex = halaqaIds.indexOf(primaryHalaqaId);
    const primaryName = text(halaqaSnaps[primaryIndex]?.data()?.name);
    const now = FieldValue.serverTimestamp();
    tx.create(awardRef, {
      studentId: recipients[0],
      studentName,
      ...(studentImageUrl ? { studentImageUrl } : {}),
      type,
      halaqaId: primaryHalaqaId,
      halaqaIds,
      ...(primaryName ? { halaqaName: primaryName } : {}),
      ...(halaqaNames.length ? { halaqaNames } : {}),
      recipientStudentIds: recipients,
      recipientCount: recipients.length,
      ...(description ? { description } : {}),
      ...(imageUrl ? { imageUrl } : {}),
      ...(imageStoragePath ? { imageStoragePath } : {}),
      title,
      note: title,
      grantedBy: uid,
      issuedBy: uid,
      grantedAt: now,
      date: now,
    });
    for (const ref of profileRefs) {
      tx.update(ref, {
        totalStars: FieldValue.increment(AWARD_STARS_PER_RECIPIENT),
      });
    }
    return { awardId, recipientCount: recipients.length, alreadyGranted: false };
  });
}

/** Mirror of kSupervisorAwardTypeOptions (lib/features/supervisor). */
export const RECORD_ONLY_TYPE_KEYS: readonly string[] = Object.freeze([
  "star",
  "badge",
  "certificate",
]);

export type IssueAchievementResult = {
  achievementId: string;
  alreadyIssued: boolean;
};

/**
 * Record-only achievement (no star credit): one student on the roster of a
 * halaqa the caller may grant in. Same doc shape the client used to write.
 * Replaying `achievementId` by the same issuer returns the original record;
 * an id already used by someone else or by a credited award is rejected.
 */
export async function issueAchievementCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<IssueAchievementResult> {
  const uid = requireCallerUid(callerUid);
  const achievementId = requireText(data.achievementId, "achievementId", 64);
  if (!AWARD_ID_PATTERN.test(achievementId)) {
    throw new HttpsError("invalid-argument", "achievementId غير صالح");
  }
  const type = requireText(data.type, "type", 64);
  if (!RECORD_ONLY_TYPE_KEYS.includes(type)) {
    throw new HttpsError("invalid-argument", "نوع الإنجاز غير صالح");
  }
  const title = requireText(data.title, "title", 120);
  const titleViolation = contactInfoViolation(title);
  if (titleViolation) {
    throw new HttpsError("invalid-argument", titleViolation);
  }
  const studentId = requireText(data.studentId, "studentId", 128);
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);

  const role = await loadCallerRole(db, uid);
  if (!GRANTOR_ROLES.has(role)) {
    throw new HttpsError("permission-denied", "منح الإنجازات متاح للمعلم والمشرف والإدارة فقط");
  }

  const ref = db.collection("achievements").doc(achievementId);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      const prior = existing.data() ?? {};
      if (text(prior.grantedBy) !== uid || isCreditedAward(prior)) {
        throw new HttpsError("already-exists", "معرّف الإنجاز مستخدم");
      }
      assertSamePayload(
        text(prior.type) === type &&
          text(prior.title) === title &&
          text(prior.studentId) === studentId &&
          text(prior.halaqaId) === halaqaId,
      );
      return { achievementId, alreadyIssued: true };
    }

    const halaqaSnap = await tx.get(halaqaRef);
    if (!halaqaSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    const halaqa = halaqaSnap.data() ?? {};
    if (!canGrantInHalaqa(role, uid, halaqa)) {
      throw new HttpsError("permission-denied", "لا تملك صلاحية منح إنجازات في هذه الحلقة");
    }
    if (!stringList(halaqa.studentIds).includes(studentId)) {
      throw new HttpsError("permission-denied", "الطالب ليس ضمن هذه الحلقة");
    }

    const now = FieldValue.serverTimestamp();
    tx.create(ref, {
      studentId,
      type,
      halaqaId,
      title,
      note: title,
      grantedBy: uid,
      issuedBy: uid,
      grantedAt: now,
      date: now,
    });
    return { achievementId, alreadyIssued: false };
  });
}

export const issueAchievement = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("issueAchievement");
    return issueAchievementCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

export const grantAward = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("grantAward");
    return grantAwardCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
