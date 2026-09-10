import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
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
 * - Writes an auditLogs summary entry
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
      // Nothing to migrate from users; still ensure we don't leave empty work.
      skipped += 1;
      continue;
    }

    const batch = db.batch();

    if (existingPrivate.length > 0) {
      // Preserve existing private phone; only strip legacy users.phone.
      preservedExistingPrivate += 1;
      batch.update(doc.ref, { phone: FieldValue.delete() });
      await batch.commit();
      migrated += 1;
      continue;
    }

    // Copy legacy → private, then remove legacy in the same atomic batch.
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

  await db.collection("auditLogs").add({
    action: "admin_migrate_user_phones",
    actorUid,
    scanned: snap.size,
    migrated,
    skipped,
    preservedExistingPrivate,
    createdAt: FieldValue.serverTimestamp(),
    source: "adminMigrateUserPhones",
  });

  return {
    scanned: snap.size,
    migrated,
    skipped,
    preservedExistingPrivate,
  };
});
