/**
 * Admin member search (parents, staff) needs a bounded, indexed prefix query
 * rather than downloading every user. `users.nameNormalized` is the Arabic-
 * normalized form of `name`, written by the server when it creates an account.
 * No `users` trigger maintains it: seeded-data triggers may only write derived
 * projections (seed_emulator_triggers_contract).
 *
 * Accounts created before this field existed are stamped by the Admin-only,
 * cursor-resumable backfill below — implemented, NOT executed by this mission.
 */

import * as admin from "firebase-admin";
import { FieldPath } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { assertCallerIsAdmin } from "../admin/assertAdmin";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, migrationTargetId, writeAuditLog } from "../audit/auditLogWrite";
import { assertBackendAllowed } from "../productionGate";
import { normalizeArabicSearchText } from "../search/arabicNormalization";

const REGION = "europe-west1";
const DEFAULT_PAGE_SIZE = 200;
const MAX_PAGE_SIZE = 400;

/** The value to write, or null when `nameNormalized` is already current. */
export function nameNormalizedPatch(user: Record<string, unknown> | undefined): string | null {
  if (!user) return null;
  const name = typeof user.name === "string" ? user.name : "";
  const normalized = normalizeArabicSearchText(name);
  return user.nameNormalized === normalized ? null : normalized;
}

export type NameBackfillResult = {
  dryRun: boolean;
  scanned: number;
  stamped: number;
  alreadySet: number;
  nextCursor: string | null;
  done: boolean;
};

export async function adminBackfillUserNameNormalizedCore(
  db: admin.firestore.Firestore,
  actorId: string,
  data: Record<string, unknown>,
): Promise<NameBackfillResult> {
  const rawSize = data.pageSize ?? DEFAULT_PAGE_SIZE;
  if (typeof rawSize !== "number" || !Number.isInteger(rawSize) || rawSize <= 0) {
    throw new HttpsError("invalid-argument", "pageSize غير صالح");
  }
  const pageSize = Math.min(rawSize, MAX_PAGE_SIZE);
  const cursor = typeof data.cursor === "string" && data.cursor.trim() ? data.cursor.trim() : null;
  const dryRun = data.dryRun !== false;

  let query = db.collection("users").orderBy(FieldPath.documentId()).limit(pageSize);
  if (cursor !== null) query = query.startAfter(cursor);
  const page = await query.get();

  let stamped = 0;
  const batch = db.batch();
  for (const doc of page.docs) {
    const patch = nameNormalizedPatch(doc.data());
    if (patch === null) continue;
    stamped += 1;
    if (!dryRun) batch.update(doc.ref, { nameNormalized: patch });
  }
  if (!dryRun && stamped > 0) await batch.commit();

  const done = page.size < pageSize;
  const nextCursor = done || page.empty ? null : page.docs[page.docs.length - 1].id;
  const result = { dryRun, scanned: page.size, stamped, alreadySet: page.size - stamped, nextCursor, done };
  if (!dryRun && stamped > 0) {
    await writeAuditLog(
      {
        actor: adminActor(actorId),
        action: AUDIT_ACTION.userNameBackfill,
        targetType: AUDIT_TARGET_TYPE.migration,
        targetId: migrationTargetId("user_name_bf", cursor ?? "start"),
        metadata: { scanned: page.size, stamped, alreadySet: result.alreadySet, cursor, nextCursor },
        source: "adminBackfillUserNameNormalized",
      },
      db,
    );
  }
  return result;
}

/** Defaults to a dry run; deliberately not invoked anywhere. */
export const adminBackfillUserNameNormalized = onCall({ region: REGION }, async (request) => {
  assertBackendAllowed("adminBackfillUserNameNormalized");
  const actorId = await assertCallerIsAdmin(request.auth?.uid);
  return adminBackfillUserNameNormalizedCore(
    admin.firestore(),
    actorId,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
