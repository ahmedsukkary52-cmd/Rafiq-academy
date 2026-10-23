/**
 * WA-15 / C14.3 — Admin-only student lifecycle transitions.
 *
 * DEFERRED INTEGRATION (known, intentional):
 * D21 states that archived students "must not remain in active Halaqa
 * rosters". WA-15 deliberately does NOT cascade into `halaqat.studentIds`,
 * because that single write would fan out into the WA-14 `studentSearch`
 * projection, the WA-10 group-conversation membership sync, and live
 * operational rosters. Roster removal is deferred to a dedicated
 * membership/archive integration wave. Until then, archiving is an
 * operational label only and the roster is left exactly as it was.
 */

import * as admin from "firebase-admin";
import { FieldPath } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { assertCallerIsAdmin } from "../admin/assertAdmin";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import {
  adminActor,
  migrationTargetId,
  writeAuditLog,
} from "../audit/auditLogWrite";
import { assertBackendAllowed } from "../productionGate";
import {
  LIFECYCLE_ACTIVE,
  LIFECYCLE_AUDIT_ACTION,
  LifecycleAction,
  LifecycleValue,
  normalizeLifecycle,
  parseLifecycleAction,
  STUDENT_PROFILES_COLLECTION,
  STUDENT_ROLE,
  USERS_COLLECTION,
} from "./studentLifecycleContract";
import {
  buildLifecycleUpdate,
  decideLifecycleTransition,
  LifecycleRejection,
} from "./studentLifecycleTransition";

const REGION = "europe-west1";
const DEFAULT_BACKFILL_PAGE_SIZE = 200;
const MAX_BACKFILL_PAGE_SIZE = 500;

type SetLifecycleRequest = {
  studentId?: unknown;
  action?: unknown;
};

type SetLifecycleResponse = {
  studentId: string;
  action: LifecycleAction;
  lifecycle: LifecycleValue;
  changed: boolean;
};

function asRecord(raw: unknown): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  return raw as Record<string, unknown>;
}

function requireStudentId(raw: unknown): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", "studentId غير صالح");
  }
  return raw.trim();
}

function rejectionToError(reason: LifecycleRejection): HttpsError {
  switch (reason) {
    case "student_not_found":
      return new HttpsError("not-found", "الطالب غير موجود");
    case "not_a_student":
      return new HttpsError(
        "failed-precondition",
        "هذه العملية متاحة لحسابات الطلاب فقط",
      );
    case "profile_not_found":
      return new HttpsError("not-found", "ملف الطالب غير موجود");
  }
}

/**
 * Archive / unarchive one student.
 *
 * Writes exactly one field on exactly one document. It never touches
 * `users.isActive`, `users.role`, `paymentAccess`, `halaqat.studentIds`, or
 * any historical record, and it never deletes the student.
 *
 * Idempotent: re-issuing a satisfied action succeeds with `changed: false`,
 * performing no write and emitting no audit entry.
 */
export const adminSetStudentLifecycle = onCall(
  { region: REGION },
  async (request): Promise<SetLifecycleResponse> => {
    assertBackendAllowed("adminSetStudentLifecycle");
    const actorId = await assertCallerIsAdmin(request.auth?.uid);

    const data = (request.data ?? {}) as SetLifecycleRequest;
    const studentId = requireStudentId(data.studentId);
    const action = parseLifecycleAction(data.action);
    if (action === null) {
      throw new HttpsError(
        "invalid-argument",
        "action غير صالح — archive أو unarchive فقط",
      );
    }

    const db = admin.firestore();
    const userRef = db.collection(USERS_COLLECTION).doc(studentId);
    const profileRef = db
      .collection(STUDENT_PROFILES_COLLECTION)
      .doc(studentId);

    // The transaction re-reads the profile so two concurrent Admin calls
    // converge instead of double-writing or double-auditing.
    const result = await db.runTransaction(async (tx) => {
      const [userSnap, profileSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(profileRef),
      ]);

      const decision = decideLifecycleTransition({
        action,
        subject: {
          user: userSnap.exists ? asRecord(userSnap.data()) : null,
          profile: profileSnap.exists ? asRecord(profileSnap.data()) : null,
        },
      });

      if (decision.outcome === "rejected") {
        throw rejectionToError(decision.reason);
      }
      if (decision.outcome === "noop") {
        return { lifecycle: decision.current, changed: false, from: null };
      }

      tx.update(profileRef, buildLifecycleUpdate(decision.to));
      return {
        lifecycle: decision.to,
        changed: true,
        from: decision.from as LifecycleValue | null,
      };
    });

    // C16 — audit only real transitions, outside the transaction so a retry
    // cannot duplicate the log entry for a write that never happened.
    if (result.changed && result.from !== null) {
      await writeAuditLog({
        actor: adminActor(actorId),
        action: LIFECYCLE_AUDIT_ACTION[action],
        targetType: AUDIT_TARGET_TYPE.studentProfile,
        targetId: studentId,
        metadata: {
          previousLifecycle: result.from,
          newLifecycle: result.lifecycle,
        },
        source: "adminSetStudentLifecycle",
      });
    }

    return {
      studentId,
      action,
      lifecycle: result.lifecycle,
      changed: result.changed,
    };
  },
);

// ── Optional backfill (implemented; NOT executed by WA-15) ─────────────────

type BackfillRequest = {
  pageSize?: unknown;
  cursor?: unknown;
  dryRun?: unknown;
};

type BackfillResponse = {
  dryRun: boolean;
  scanned: number;
  stamped: number;
  alreadySet: number;
  nextCursor: string | null;
  done: boolean;
};

function parsePageSize(raw: unknown): number {
  if (raw === undefined || raw === null) return DEFAULT_BACKFILL_PAGE_SIZE;
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw <= 0) {
    throw new HttpsError("invalid-argument", "pageSize غير صالح");
  }
  return Math.min(raw, MAX_BACKFILL_PAGE_SIZE);
}

function parseCursor(raw: unknown): string | null {
  if (raw === undefined || raw === null || raw === "") return null;
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", "cursor غير صالح");
  }
  return raw.trim();
}

/**
 * Stamps the explicit default `lifecycle: 'active'` on student profiles that
 * do not carry the field yet.
 *
 * This is NOT required for correctness — a missing value already reads as
 * `active` everywhere. It exists only so an operator can make the field
 * explicit later. Idempotent, cursor-resumable, and never downgrades an
 * already-archived student.
 *
 * Deliberately not invoked anywhere.
 */
export const adminBackfillStudentLifecycle = onCall(
  { region: REGION },
  async (request): Promise<BackfillResponse> => {
    assertBackendAllowed("adminBackfillStudentLifecycle");
    const actorId = await assertCallerIsAdmin(request.auth?.uid);

    const data = (request.data ?? {}) as BackfillRequest;
    const pageSize = parsePageSize(data.pageSize);
    const cursor = parseCursor(data.cursor);
    const dryRun = data.dryRun === true;

    const db = admin.firestore();
    let query = db
      .collection(USERS_COLLECTION)
      .where("role", "==", STUDENT_ROLE)
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (cursor !== null) query = query.startAfter(cursor);

    const page = await query.get();

    let stamped = 0;
    let alreadySet = 0;

    for (const doc of page.docs) {
      const profileRef = db
        .collection(STUDENT_PROFILES_COLLECTION)
        .doc(doc.id);
      const profileSnap = await profileRef.get();
      if (!profileSnap.exists) continue;

      const raw = profileSnap.data()?.lifecycle;
      if (typeof raw === "string" && normalizeLifecycle(raw) === raw) {
        alreadySet += 1;
        continue;
      }

      stamped += 1;
      // Never downgrades: the absent/malformed value already means active.
      if (!dryRun) {
        await profileRef.update(buildLifecycleUpdate(LIFECYCLE_ACTIVE));
      }
    }

    const done = page.size < pageSize;
    const nextCursor = done || page.empty
      ? null
      : page.docs[page.docs.length - 1].id;

    if (!dryRun && stamped > 0) {
      await writeAuditLog({
        actor: adminActor(actorId),
        action: AUDIT_ACTION.studentLifecycleBackfill,
        targetType: AUDIT_TARGET_TYPE.migration,
        targetId: migrationTargetId(
          "lifecycle_bf",
          cursor ?? "start",
        ),
        metadata: {
          scanned: page.size,
          stamped,
          alreadySet,
          cursor,
          nextCursor,
        },
        source: "adminBackfillStudentLifecycle",
      });
    }

    return { dryRun, scanned: page.size, stamped, alreadySet, nextCursor, done };
  },
);
