/**
 * PH-02 / P0-05 — the student coin economy is server-authoritative.
 *
 * Earn: lesson-homework completion. The required task kinds and the reward
 * come from the canonical lesson-homework contract
 * (AssignmentModel.defaultHomeworkFields: reading 20, listening 15,
 * recitation 30) filtered by the capabilities enabled on the server — never
 * from the client-editable `tasks` list, its `points`, or which kinds it
 * contains. The student's `tasks[].isCompleted` ticks are completion evidence
 * only, and only for kinds the server requires.
 *
 * Exactly-once: `homeworkRewards/{assignmentId}` (server-only) is created in
 * the same transaction as the credit. Any later call — retry, replay, a stale
 * client, or a Teacher reopening the homework — finds the marker and never
 * credits again. Legacy completions (before the marker existed) are detected
 * by the server-set `completedAt`.
 *
 * `points` is QUARANTINED (reserved for a future games/learning system): it is
 * no longer credited, and existing values are left untouched.
 *
 * Spend: avatar unlock. The price comes from the trusted catalog below
 * (mirror of lib/features/student/domain/entities/avatar_catalog.dart, kept in
 * parity by functions tests). The client sends only `avatarId`.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  loadCallerRole,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";

/** avatarId → unlock cost in coins (0 = free from the start). */
export const AVATAR_CATALOG: Readonly<Record<string, number>> = Object.freeze({
  panda: 0,
  fox: 0,
  lion: 0,
  wizard: 500,
  rabbit: 0,
  owl: 0,
  champion: 300,
  star: 1200,
  camel: 800,
});

/** StudentProfileEntity default when `unlockedAvatarIds` was never written. */
export const DEFAULT_UNLOCKED_AVATAR_IDS = Object.freeze([
  "fox",
  "panda",
  "lion",
  "rabbit",
  "owl",
]);

/** Canonical homework task kinds and their fixed credit. */
export const HOMEWORK_TASK_POINTS: Readonly<Record<string, number>> = Object.freeze({
  reading: 20,
  listening: 15,
  recitation: 30,
});

export const MAX_HOMEWORK_CREDIT = 100;

export const HOMEWORK_REWARDS_COLLECTION = "homeworkRewards";

/** `assignments.kind` wire values accepted as lesson homework. */
export const LESSON_HOMEWORK_KINDS: readonly string[] = Object.freeze([
  "lessonHomework",
  "",
]);

/**
 * Server mirror of `AppCapabilities.audioUploadsEnabled` (client) and the
 * Storage `recitations/**` deny rule. While false, recitation cannot be
 * submitted, so it is never a completion requirement.
 */
export const SERVER_CAPABILITIES = Object.freeze({ audioUploadsEnabled: false });

/** Required kinds for lesson homework under the given capabilities. */
export function requiredHomeworkKinds(
  capabilities: { audioUploadsEnabled: boolean } = SERVER_CAPABILITIES,
): string[] {
  const kinds = ["reading", "listening"];
  if (capabilities.audioUploadsEnabled) kinds.push("recitation");
  return kinds;
}

/** Fixed reward for completing every required kind (capped). */
export function rewardForRequiredKinds(kinds: readonly string[]): number {
  let total = 0;
  for (const kind of new Set(kinds)) total += HOMEWORK_TASK_POINTS[kind] ?? 0;
  return Math.min(total, MAX_HOMEWORK_CREDIT);
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function balance(raw: unknown): number {
  return typeof raw === "number" && Number.isInteger(raw) && raw > 0 ? raw : 0;
}

async function requireStudent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<void> {
  if ((await loadCallerRole(db, uid)) !== "student") {
    throw new HttpsError("permission-denied", "هذه العملية متاحة للطالب فقط");
  }
}

type HomeworkTask = { kind: string; isCompleted: boolean; recitationRecordId: string };

function parseTasks(raw: unknown): HomeworkTask[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((t): t is Record<string, unknown> => typeof t === "object" && t !== null)
    .map((t) => ({
      kind: text(t.kind),
      isCompleted: t.isCompleted === true,
      recitationRecordId: text(t.recitationRecordId),
    }));
}

/** Each canonical kind credits once, bounded by MAX_HOMEWORK_CREDIT. */
export function homeworkReward(tasks: readonly HomeworkTask[]): number {
  const kinds = new Set(
    tasks.filter((t) => t.isCompleted).map((t) => t.kind),
  );
  let total = 0;
  for (const kind of kinds) total += HOMEWORK_TASK_POINTS[kind] ?? 0;
  return Math.min(total, MAX_HOMEWORK_CREDIT);
}

export type CompleteHomeworkResult = {
  assignmentId: string;
  awardedCoins: number;
  /** Legacy alias of `awardedCoins` for clients that predate P0-05. */
  awardedPoints: number;
  alreadyRewarded: boolean;
};

export async function completeHomeworkCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  capabilities: { audioUploadsEnabled: boolean } = SERVER_CAPABILITIES,
): Promise<CompleteHomeworkResult> {
  const uid = requireCallerUid(callerUid);
  const assignmentId = requireText(data.assignmentId, "assignmentId");
  await requireStudent(db, uid);

  const assignmentRef = db.collection("assignments").doc(assignmentId);
  const profileRef = db.collection("studentProfiles").doc(uid);
  const rewardRef = db.collection(HOMEWORK_REWARDS_COLLECTION).doc(assignmentId);

  return db.runTransaction(async (tx) => {
    const [snap, rewardSnap] = await tx.getAll(assignmentRef, rewardRef);
    if (!snap.exists) throw new HttpsError("not-found", "التكليف غير موجود");
    const a = snap.data() ?? {};
    if (text(a.studentId) !== uid) {
      throw new HttpsError("permission-denied", "هذا التكليف لا يخصك");
    }
    if (!LESSON_HOMEWORK_KINDS.includes(text(a.kind))) {
      throw new HttpsError("failed-precondition", "هذه مهمة حلقة وليست واجباً");
    }

    const alreadyCompleted = a.isSubmitted === true || a.status === "completed";
    const alreadyRewarded = rewardSnap.exists || a.completedAt != null;
    if (alreadyRewarded) {
      if (!alreadyCompleted) {
        tx.update(assignmentRef, { isSubmitted: true, status: "completed" });
      }
      return { assignmentId, awardedCoins: 0, awardedPoints: 0, alreadyRewarded: true };
    }
    if (alreadyCompleted) {
      throw new HttpsError("failed-precondition", "تم إنهاء هذا الواجب مسبقاً");
    }

    const required = requiredHomeworkKinds(capabilities);
    const tasks = parseTasks(a.tasks);
    const ticked = new Set(tasks.filter((t) => t.isCompleted).map((t) => t.kind));
    if (required.some((kind) => !ticked.has(kind))) {
      throw new HttpsError("failed-precondition", "لم تكتمل المهام المطلوبة بعد");
    }

    if (required.includes("recitation")) {
      const recordId = tasks.find(
        (t) => t.kind === "recitation" && t.isCompleted,
      )?.recitationRecordId;
      const record = await tx.get(
        db.collection("recitationRecords").doc(recordId || "_missing"),
      );
      const r = record.data();
      if (
        !record.exists ||
        text(r?.studentId) !== uid ||
        text(r?.assignmentId) !== assignmentId ||
        !text(r?.storagePath).startsWith(`recitations/${uid}/${assignmentId}/`)
      ) {
        throw new HttpsError("failed-precondition", "مهمة التسميع لم تُرسل بعد");
      }
    }

    const profileSnap = await tx.get(profileRef);
    if (!profileSnap.exists) throw new HttpsError("not-found", "ملف الطالب غير موجود");

    const reward = rewardForRequiredKinds(required);
    tx.update(assignmentRef, {
      isSubmitted: true,
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
    });
    tx.create(rewardRef, {
      assignmentId,
      studentId: uid,
      coins: reward,
      requiredKinds: required,
      rewardedAt: FieldValue.serverTimestamp(),
    });
    if (reward > 0) {
      tx.update(profileRef, {
        coins: FieldValue.increment(reward),
        lastCompletedHomeworkId: assignmentId,
      });
    }
    return { assignmentId, awardedCoins: reward, awardedPoints: reward, alreadyRewarded: false };
  });
}

export type PurchaseAvatarResult = {
  avatarId: string;
  coins: number;
  unlockedAvatarIds: string[];
  debited: number;
};

/**
 * Select (and, when locked, unlock) an avatar. Idempotent: an avatar that is
 * already unlocked or free is only selected, never charged twice.
 */
export async function purchaseAvatarCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<PurchaseAvatarResult> {
  const uid = requireCallerUid(callerUid);
  const avatarId = requireText(data.avatarId, "avatarId", 64);
  if (!Object.prototype.hasOwnProperty.call(AVATAR_CATALOG, avatarId)) {
    throw new HttpsError("not-found", "الشخصية غير موجودة");
  }
  const cost = AVATAR_CATALOG[avatarId];
  await requireStudent(db, uid);

  const profileRef = db.collection("studentProfiles").doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(profileRef);
    if (!snap.exists) throw new HttpsError("not-found", "ملف الطالب غير موجود");
    const profile = snap.data() ?? {};
    const coins = balance(profile.coins);
    const unlocked = Array.isArray(profile.unlockedAvatarIds)
      ? stringList(profile.unlockedAvatarIds)
      : [...DEFAULT_UNLOCKED_AVATAR_IDS];

    if (cost === 0 || unlocked.includes(avatarId)) {
      tx.update(profileRef, { avatarId, updatedAt: FieldValue.serverTimestamp() });
      return { avatarId, coins, unlockedAvatarIds: unlocked, debited: 0 };
    }
    if (coins < cost) {
      throw new HttpsError(
        "failed-precondition",
        `عملاتك غير كافية لفتح هذه الشخصية (المطلوب ${cost})`,
      );
    }
    const nextUnlocked = [...unlocked, avatarId];
    tx.update(profileRef, {
      avatarId,
      unlockedAvatarIds: nextUnlocked,
      coins: coins - cost,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {
      avatarId,
      coins: coins - cost,
      unlockedAvatarIds: nextUnlocked,
      debited: cost,
    };
  });
}

export const completeHomework = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("completeHomework");
    return completeHomeworkCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

export const purchaseAvatar = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("purchaseAvatar");
    return purchaseAvatarCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
