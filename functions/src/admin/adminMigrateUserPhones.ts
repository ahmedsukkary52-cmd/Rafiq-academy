import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import {
  adminActor,
  migrationTargetId,
  writeAuditLog,
} from "../audit/auditLogWrite";
import { assertBackendAllowed } from "../productionGate";
import { assertCallerIsAdmin } from "./assertAdmin";

interface MigrateResult {
  scanned: number;
  migrated: number;
  skipped: number;
  preservedExistingPrivate: number;
}

/**
 * Moves legacy non-empty users.phone → userPrivate/{uid}.phone and removes
 * phone from the users document so non-Admin identity reads no longer leak D16.
 *
 * Safety:
 * - Admin-only + billing/emulator gate
 * - Does NOT overwrite a non-empty existing userPrivate.phone with users.phone
 * - Deletes users.phone only after userPrivate has a non-empty phone
 * - Idempotent / safe to re-run
 * - Writes a C16 audit summary only when meaningful work occurred
 *
 * DO NOT run against production until B-BILLING Verified and operators confirm.
 */
export const adminMigrateUserPhones = onCall<
  Record<string, never>,
  Promise<MigrateResult>
>({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminMigrateUserPhones");
  const actorUid = await assertCallerIsAdmin(request.auth?.uid);

  const db = admin.firestore();
  const snap = await db.collection("users").get();

  let migrated = 0;
  let skipped = 0;
  let preservedExistingPrivate = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const legacyPhone =
      typeof data.phone === "string" ? data.phone.trim() : "";

    const privateRef = db.collection("userPrivate").doc(doc.id);
    const privateSnap = await privateRef.get();
    const existingPrivate =
      typeof privateSnap.data()?.phone === "string"
        ? (privateSnap.data()!.phone as string).trim()
        : "";

    if (!legacyPhone) {
      skipped += 1;
      continue;
    }

    const batch = db.batch();

    if (existingPrivate.length > 0) {
      preservedExistingPrivate += 1;
      batch.update(doc.ref, { phone: FieldValue.delete() });
      await batch.commit();
      migrated += 1;
      continue;
    }

    batch.set(
      privateRef,
      {
        phone: legacyPhone,
        updatedAt: FieldValue.serverTimestamp(),
        migratedFromUsers: true,
      },
      { merge: true },
    );
    batch.update(doc.ref, { phone: FieldValue.delete() });
    await batch.commit();
    migrated += 1;
  }

  if (migrated > 0) {
    await writeAuditLog({
      actor: adminActor(actorUid),
      action: AUDIT_ACTION.migrateUserPhones,
      targetType: AUDIT_TARGET_TYPE.migration,
      targetId: migrationTargetId("phones_migrate", "full"),
      metadata: {
        scanned: snap.size,
        migratedCount: migrated,
        skippedCount: skipped,
        preservedExistingPrivate,
      },
      source: "adminMigrateUserPhones",
    });
  }

  return {
    scanned: snap.size,
    migrated,
    skipped,
    preservedExistingPrivate,
  };
});
