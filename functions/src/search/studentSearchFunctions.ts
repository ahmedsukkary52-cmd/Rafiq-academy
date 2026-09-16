/**
 * WA-14 / C13 — `studentSearch` materializers (server-owned projection).
 *
 * Three triggers keep the projection live; an Admin-only callable backfills
 * existing students. Nothing here writes back to `users`, `studentProfiles` or
 * `halaqat`, and `studentSearch` has no trigger of its own, so fan-out loops
 * are structurally impossible.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { assertCallerIsAdmin } from "../admin/assertAdmin";
import { assertBackendAllowed } from "../productionGate";
import {
  projectionGateBlockedMessage,
  resolveProjectionRunMode,
} from "./projectionGate";
import {
  HALAQA_ID_FIELD,
  HALAQA_NAME_FIELD,
  HALAQAT_COLLECTION,
  STUDENT_PROFILES_COLLECTION,
  STUDENT_ROLE,
  STUDENT_SEARCH_COLLECTION,
  trimmedString,
  UPDATED_AT_FIELD,
  USERS_COLLECTION,
} from "./studentSearchContract";
import {
  affectedStudentIds,
  buildStudentSearchDocument,
  classifyHalaqaChange,
  decideStudentSearchWrite,
  HalaqaMembershipDoc,
  HalaqaProjectionSource,
  StudentProfileSource,
  StudentSearchSources,
  studentProfileProjectionFieldsChanged,
  UserSource,
  userProjectionFieldsChanged,
} from "./studentSearchProjection";

const REGION = "europe-west1";
/** Firestore caps a batch at 500 writes; stay well under it. */
const WRITE_CHUNK = 200;
const DEFAULT_BACKFILL_PAGE_SIZE = 200;
const MAX_BACKFILL_PAGE_SIZE = 500;

type ApplyOutcome = "created" | "updated" | "unchanged" | "deleted";

function asRecord(raw: unknown): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  return raw as Record<string, unknown>;
}

function asUserSource(raw: unknown): UserSource {
  const data = asRecord(raw);
  return data === null ? null : { name: data.name, role: data.role };
}

function asProfileSource(raw: unknown): StudentProfileSource {
  const data = asRecord(raw);
  return data === null ? null : { name: data.name, halaqaId: data.halaqaId };
}

function asHalaqaSource(raw: unknown): HalaqaProjectionSource | undefined {
  const data = asRecord(raw);
  if (data === null) return undefined;
  return {
    name: data.name,
    teacherId: data.teacherId,
    supervisorId: data.supervisorId,
    studentIds: data.studentIds,
  };
}

function chunk<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * Reads the three sources for one student. Missing documents resolve to
 * `null`/empty rather than throwing, so drift can never fail a trigger.
 */
async function loadSources(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<StudentSearchSources> {
  const [userSnap, profileSnap, halaqatSnap] = await Promise.all([
    db.collection(USERS_COLLECTION).doc(studentId).get(),
    db.collection(STUDENT_PROFILES_COLLECTION).doc(studentId).get(),
    db
      .collection(HALAQAT_COLLECTION)
      .where("studentIds", "array-contains", studentId)
      .get(),
  ]);

  const memberships: HalaqaMembershipDoc[] = halaqatSnap.docs.map((doc) => {
    const data = asRecord(doc.data()) ?? {};
    return {
      halaqaId: doc.id,
      name: data.name,
      teacherId: data.teacherId,
      supervisorId: data.supervisorId,
    };
  });

  return {
    studentId,
    user: userSnap.exists ? asUserSource(userSnap.data()) : null,
    profile: profileSnap.exists ? asProfileSource(profileSnap.data()) : null,
    memberships,
  };
}

/**
 * Recomputes and converges one projection inside a transaction on the target
 * document. Sources are read first; the transaction re-reads only the
 * projection so concurrent triggers converge on the same derived value.
 */
async function applyStudentProjection(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<ApplyOutcome> {
  const id = trimmedString(studentId);
  if (id.length === 0) return "unchanged";

  const sources = await loadSources(db, id);
  const ref = db.collection(STUDENT_SEARCH_COLLECTION).doc(id);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const decision = decideStudentSearchWrite({
      sources,
      existing: snap.exists ? asRecord(snap.data()) : null,
    });

    if (decision.action === "noop") return "unchanged";
    if (decision.action === "delete") {
      tx.delete(ref);
      return "deleted";
    }

    tx.set(
      ref,
      buildStudentSearchDocument(
        decision.projection,
        FieldValue.serverTimestamp(),
      ),
    );
    return decision.action === "create" ? "created" : "updated";
  });
}

/** Sequential on purpose: bounded fan-out beats a burst of parallel writes. */
async function applyMany(
  db: admin.firestore.Firestore,
  studentIds: readonly string[],
): Promise<void> {
  for (const studentId of studentIds) {
    await applyStudentProjection(db, studentId);
  }
}

// ── Trigger 1 — users/{uid} ────────────────────────────────────────────────

/**
 * Name / role / existence changes. Creates the projection when a user becomes
 * a student and deletes it when the user is removed or stops being one.
 */
export const projectStudentSearchOnUserWrite = onDocumentWritten(
  { region: REGION, document: `${USERS_COLLECTION}/{uid}` },
  async (event) => {
    if (resolveProjectionRunMode() === "blocked") {
      console.warn(
        projectionGateBlockedMessage("projectStudentSearchOnUserWrite"),
      );
      return;
    }

    const uid = trimmedString(event.params.uid);
    if (uid.length === 0) return;

    const before = event.data?.before?.exists
      ? asUserSource(event.data.before.data())
      : undefined;
    const after = event.data?.after?.exists
      ? asUserSource(event.data.after.data())
      : undefined;

    if (!userProjectionFieldsChanged(before, after)) return;

    await applyStudentProjection(admin.firestore(), uid);
  },
);

// ── Trigger 2 — studentProfiles/{studentId} ────────────────────────────────

/** Fallback-name and primary-pointer changes. */
export const projectStudentSearchOnProfileWrite = onDocumentWritten(
  { region: REGION, document: `${STUDENT_PROFILES_COLLECTION}/{studentId}` },
  async (event) => {
    if (resolveProjectionRunMode() === "blocked") {
      console.warn(
        projectionGateBlockedMessage("projectStudentSearchOnProfileWrite"),
      );
      return;
    }

    const studentId = trimmedString(event.params.studentId);
    if (studentId.length === 0) return;

    const before = event.data?.before?.exists
      ? asProfileSource(event.data.before.data())
      : undefined;
    const after = event.data?.after?.exists
      ? asProfileSource(event.data.after.data())
      : undefined;

    if (!studentProfileProjectionFieldsChanged(before, after)) return;

    await applyStudentProjection(admin.firestore(), studentId);
  },
);

// ── Trigger 3 — halaqat/{halaqaId} ─────────────────────────────────────────

/**
 * Rename, staff change, roster change and deletion.
 *
 * A rename with an unchanged roster only rewrites `halaqaName` on the rows
 * where this halaqa is the display primary — no `users`/`studentProfiles`
 * reads. Everything else recomputes the union of the before/after rosters.
 * Losing a halaqa never deletes a student's projection.
 */
export const projectStudentSearchOnHalaqaWrite = onDocumentWritten(
  { region: REGION, document: `${HALAQAT_COLLECTION}/{halaqaId}` },
  async (event) => {
    if (resolveProjectionRunMode() === "blocked") {
      console.warn(
        projectionGateBlockedMessage("projectStudentSearchOnHalaqaWrite"),
      );
      return;
    }

    const halaqaId = trimmedString(event.params.halaqaId);
    if (halaqaId.length === 0) return;

    const before = event.data?.before?.exists
      ? asHalaqaSource(event.data.before.data())
      : undefined;
    const after = event.data?.after?.exists
      ? asHalaqaSource(event.data.after.data())
      : undefined;

    const change = classifyHalaqaChange({ before, after });
    if (change === "none") return;

    const db = admin.firestore();

    if (change === "rename_only") {
      await renameHalaqaInProjections({
        db,
        halaqaId,
        halaqaName: trimmedString(after?.name),
      });
      return;
    }

    await applyMany(db, affectedStudentIds({ before, after }));
  },
);

/** Cheap rename path — one query plus chunked batch updates. */
async function renameHalaqaInProjections(params: {
  db: admin.firestore.Firestore;
  halaqaId: string;
  halaqaName: string;
}): Promise<void> {
  const { db, halaqaId, halaqaName } = params;
  const snap = await db
    .collection(STUDENT_SEARCH_COLLECTION)
    .where(HALAQA_ID_FIELD, "==", halaqaId)
    .get();
  if (snap.empty) return;

  for (const group of chunk(snap.docs, WRITE_CHUNK)) {
    const batch = db.batch();
    for (const doc of group) {
      batch.update(doc.ref, {
        [HALAQA_NAME_FIELD]: halaqaName,
        [UPDATED_AT_FIELD]: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// ── Admin backfill callable (implemented; not executed by WA-14) ───────────

type BackfillRequest = {
  pageSize?: unknown;
  cursor?: unknown;
  dryRun?: unknown;
};

type BackfillResponse = {
  dryRun: boolean;
  scanned: number;
  created: number;
  updated: number;
  unchanged: number;
  deleted: number;
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
 * Cursor-resumable backfill over `users where role == 'student'`, ordered by
 * document id. Idempotent (the same convergence decision as the triggers),
 * non-destructive, and it never repairs a source document.
 *
 * Deliberately not invoked anywhere — an operator runs it after B-BILLING.
 */
export const adminBackfillStudentSearch = onCall(
  { region: REGION },
  async (request): Promise<BackfillResponse> => {
    assertBackendAllowed("adminBackfillStudentSearch");
    const actorId = await assertCallerIsAdmin(request.auth?.uid);

    const data = (request.data ?? {}) as BackfillRequest;
    const pageSize = parsePageSize(data.pageSize);
    const cursor = parseCursor(data.cursor);
    const dryRun = data.dryRun === true;

    const db = admin.firestore();
    let query = db
      .collection(USERS_COLLECTION)
      .where("role", "==", STUDENT_ROLE)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (cursor !== null) query = query.startAfter(cursor);

    const page = await query.get();

    let created = 0;
    let updated = 0;
    let unchanged = 0;
    let deleted = 0;

    for (const doc of page.docs) {
      if (dryRun) {
        const sources = await loadSources(db, doc.id);
        const existing = await db
          .collection(STUDENT_SEARCH_COLLECTION)
          .doc(doc.id)
          .get();
        const decision = decideStudentSearchWrite({
          sources,
          existing: existing.exists ? asRecord(existing.data()) : null,
        });
        if (decision.action === "create") created += 1;
        else if (decision.action === "update") updated += 1;
        else if (decision.action === "delete") deleted += 1;
        else unchanged += 1;
        continue;
      }

      const outcome = await applyStudentProjection(db, doc.id);
      if (outcome === "created") created += 1;
      else if (outcome === "updated") updated += 1;
      else if (outcome === "deleted") deleted += 1;
      else unchanged += 1;
    }

    const done = page.size < pageSize;
    const nextCursor = done || page.empty
      ? null
      : page.docs[page.docs.length - 1].id;

    if (!dryRun && (created > 0 || updated > 0 || deleted > 0)) {
      await db.collection("auditLogs").add({
        action: "student_search_backfill",
        actorId,
        scanned: page.size,
        created,
        updated,
        deleted,
        cursor,
        nextCursor,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      dryRun,
      scanned: page.size,
      created,
      updated,
      unchanged,
      deleted,
      nextCursor,
      done,
    };
  },
);
